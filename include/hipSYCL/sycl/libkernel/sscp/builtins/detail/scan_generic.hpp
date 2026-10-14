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

template <int SharedMemorySize, bool ExclusiveScan, typename OutType, typename MemoryType,
          typename BinaryOperation>
OutType wg_generic_scan(OutType x, BinaryOperation op, MemoryType shrd_mem, OutType init = 0) {

  // The last element of the shared memory is used to store the total sum for exclusive scans.
  const int shmem_array_length = SharedMemorySize - 1;

  const __acpp_uint32 wg_lid = __acpp_sscp_typed_get_local_linear_id<3, int>();
  const __acpp_int32 sg_size = __acpp_sscp_get_subgroup_size();

  const __acpp_uint32 sg_lid = __acpp_sscp_get_subgroup_local_id();
  const __acpp_uint32 num_subgroups = __acpp_sscp_get_num_subgroups();
  const __acpp_uint32 subgroup_id = __acpp_sscp_get_subgroup_id();

  const bool last_item_in_sg = sg_lid == static_cast<__acpp_uint32>(sg_size - 1);
  OutType sg_scan_result;
  if constexpr (ExclusiveScan) {
    sg_scan_result = sg_exclusive_scan(x, op, init);
  } else {
    sg_scan_result = sg_inclusive_scan(x, op);
  }

  for (int i = 0; i < (num_subgroups - 1 + shmem_array_length) / shmem_array_length; i++) {
    const __acpp_uint32 relative_thread_id = wg_lid;
    if (subgroup_id / shmem_array_length == i) {
      if (last_item_in_sg) {

        if constexpr (ExclusiveScan) {
          shrd_mem[subgroup_id % shmem_array_length] = op(sg_scan_result, x);
        } else {
          shrd_mem[subgroup_id % shmem_array_length] = sg_scan_result;
        }
      }
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
    // First shmem_array_length number of threads exclusive scan in shared memory
    OutType local_x{};
    if (relative_thread_id < shmem_array_length)
      local_x = shrd_mem[relative_thread_id];
    for (__acpp_int32 j = 1; j < shmem_array_length; j *= 2) {
      __acpp_int32 next_id = relative_thread_id - j;
      if (next_id >= 0 && j <= relative_thread_id) {
        if (relative_thread_id < shmem_array_length) {
          auto other_x = shrd_mem[next_id];
          local_x = op(local_x, other_x);
          shrd_mem[relative_thread_id] = local_x;
        }
      }
      __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                     __acpp_sscp_memory_order::acq_rel);
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);

    const bool in_segment = subgroup_id / shmem_array_length == static_cast<__acpp_uint32>(i);
    if (in_segment && subgroup_id % shmem_array_length > 0) {
      auto current_segment_update = shrd_mem[(subgroup_id % shmem_array_length) - 1];
      sg_scan_result = op(current_segment_update, sg_scan_result);
    }
    if (in_segment && i > 0) {
      sg_scan_result = op(shrd_mem[shmem_array_length], sg_scan_result);
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
    // Carry for the next segment: the running total at the end of this one,
    // written once, by the last item of the segment's last sub-group.
    const __acpp_uint32 segment_end = static_cast<__acpp_uint32>(i + 1) * shmem_array_length;
    const __acpp_uint32 last_sg_in_segment =
        (segment_end < num_subgroups ? segment_end : num_subgroups) - 1;
    if (subgroup_id == last_sg_in_segment && last_item_in_sg) {
      if constexpr (ExclusiveScan) {
        shrd_mem[shmem_array_length] = op(sg_scan_result, x);
      } else {
        shrd_mem[shmem_array_length] = sg_scan_result;
      }
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
  }
  return sg_scan_result;
}

} // namespace hipsycl::libkernel::sscp

#endif
