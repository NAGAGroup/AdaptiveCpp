/*
 * This file is part of AdaptiveCpp, an implementation of SYCL and C++ standard
 * parallelism for CPUs and GPUs.
 *
 * Copyright The AdaptiveCpp Contributors
 *
 * AdaptiveCpp is released under the BSD 2-Clause "Simplified" License.
 * See file LICENSE in the project root for full license details.
 */
// SPDX-License-Identifier: BSD-2-Clause

#ifndef HIPSYCL_SSCP_DETAIL_GENEIC_SCAN_BUILTINS_HPP
#define HIPSYCL_SSCP_DETAIL_GENEIC_SCAN_BUILTINS_HPP

#include "../core_typed.hpp"
#include "../subgroup.hpp"
#include "broadcast.hpp"
#include "scan_subgroup.hpp"
#include "shuffle.hpp"
#include "utils.hpp"

namespace hipsycl::libkernel::sscp {

// Work-group scan through shared memory, for backends without a native work-group scan.
//
// Every item first computes the INCLUSIVE scan of its sub-group (also for exclusive scans: the init
// value must be applied exactly once per work-group, not once per sub-group). The sub-group totals
// are then scanned in shared memory, segment by segment (a segment is up to shmem_array_length
// sub-groups), and each item combines the total of all earlier sub-groups into its result.
// Exclusive scans finally shift the inclusive result by one work item and apply init.
//
// Every work item reaches every work-group barrier: all loop bounds are uniform and no barrier is
// inside a divergent branch.
template <int SharedMemorySize, bool ExclusiveScan, typename OutType, typename MemoryType,
          typename BinaryOperation>
OutType wg_generic_scan(OutType x, BinaryOperation op, MemoryType shrd_mem, OutType init = 0) {

  // The last element of the shared memory is used to carry the running total across segments.
  const __acpp_uint32 shmem_array_length = SharedMemorySize - 1;

  const __acpp_uint32 wg_lid = __acpp_sscp_typed_get_local_linear_id<3, int>();
  const __acpp_int32 sg_size = __acpp_sscp_get_subgroup_size();

  const __acpp_uint32 sg_lid = __acpp_sscp_get_subgroup_local_id();
  const __acpp_uint32 num_subgroups = __acpp_sscp_get_num_subgroups();
  const __acpp_uint32 subgroup_id = __acpp_sscp_get_subgroup_id();

  const bool last_item_in_sg = sg_lid == static_cast<__acpp_uint32>(sg_size - 1);

  // Inclusive scan within the sub-group, for exclusive scans too.
  OutType sg_scan_result = sg_inclusive_scan(x, op);

  // Combined total of all sub-groups before this one (what gets op-ed into this item's result).
  // Only meaningful if has_prefix, i.e. for subgroup_id > 0.
  OutType prefix_of_earlier_subgroups{};
  bool has_prefix = false;

  const __acpp_uint32 num_segments = (num_subgroups + shmem_array_length - 1) / shmem_array_length;
  for (__acpp_uint32 i = 0; i < num_segments; i++) {
    const bool in_segment = subgroup_id / shmem_array_length == i;

    // The last item of each sub-group in this segment publishes the inclusive sub-group total.
    if (in_segment && last_item_in_sg) {
      shrd_mem[subgroup_id % shmem_array_length] = sg_scan_result;
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);

    // The first shmem_array_length work items inclusive-scan the sub-group totals in shared memory
    // (Hillis-Steele). Each step reads, barriers, then writes, barriers: a step never reads an
    // element that another item writes in the same step.
    OutType local_x{};
    if (wg_lid < shmem_array_length)
      local_x = shrd_mem[wg_lid];
    for (__acpp_uint32 j = 1; j < shmem_array_length; j *= 2) {
      const bool participates = wg_lid < shmem_array_length && wg_lid >= j;
      OutType other_x{};
      if (participates)
        other_x = shrd_mem[wg_lid - j];
      __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                     __acpp_sscp_memory_order::acq_rel);
      if (participates) {
        local_x = op(local_x, other_x);
        shrd_mem[wg_lid] = local_x;
      }
      __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                     __acpp_sscp_memory_order::acq_rel);
    }

    // Combine the totals of the earlier sub-groups into this segment's results.
    if (in_segment) {
      OutType prefix{};
      bool have = false;
      if (subgroup_id % shmem_array_length > 0) {
        prefix = shrd_mem[(subgroup_id % shmem_array_length) - 1];
        have = true;
      }
      if (i > 0) {
        prefix = have ? op(shrd_mem[shmem_array_length], prefix) : shrd_mem[shmem_array_length];
        have = true;
      }
      if (have) {
        sg_scan_result = op(prefix, sg_scan_result);
        prefix_of_earlier_subgroups = prefix;
        has_prefix = true;
      }
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);

    // Carry for the next segment: the inclusive running total at the end of this one, written once,
    // by the last item of the segment's last sub-group.
    const __acpp_uint32 segment_end = (i + 1) * shmem_array_length;
    const __acpp_uint32 last_sg_in_segment =
        (segment_end < num_subgroups ? segment_end : num_subgroups) - 1;
    if (subgroup_id == last_sg_in_segment && last_item_in_sg) {
      shrd_mem[shmem_array_length] = sg_scan_result;
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
  }

  if constexpr (ExclusiveScan) {
    // sg_scan_result is now the work-group-wide inclusive result. The exclusive result is
    // init op (inclusive result of the previous work item in linear order). The shift is a
    // sub-group collective, so every lane executes it.
    const OutType prev_in_sg = __builtin_bit_cast(
        OutType, sg_shift_right(__builtin_bit_cast(typename integer_type<OutType>::type, sg_scan_result), 1));
    if (wg_lid == 0)
      return init;
    // Lane 0 of sub-group k > 0 has no predecessor in its sub-group: its predecessor is the last
    // item of sub-group k-1, whose inclusive result is the total of sub-groups 0..k-1.
    const OutType prev = (sg_lid == 0 && has_prefix) ? prefix_of_earlier_subgroups : prev_in_sg;
    return op(init, prev);
  } else {
    return sg_scan_result;
  }
}

} // namespace hipsycl::libkernel::sscp

#endif
