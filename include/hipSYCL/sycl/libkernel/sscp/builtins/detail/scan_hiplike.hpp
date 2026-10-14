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

#ifndef HIPSYCL_SSCP_DETAIL_HIPLIKE_SCAN_BUILTINS_HPP
#define HIPSYCL_SSCP_DETAIL_HIPLIKE_SCAN_BUILTINS_HPP

#include "../core_typed.hpp"
#include "../subgroup.hpp"
#include "broadcast.hpp"
#include "scan_subgroup.hpp"
#include "shuffle.hpp"
#include "utils.hpp"

namespace hipsycl::libkernel::sscp {

// Work-group scan for hip-like backends (at most one sub-group of sub-group totals).
//
// Every item computes the INCLUSIVE scan of its sub-group, also for exclusive scans: applying init
// inside every sub-group would count it once per sub-group. Sub-group 0 then scans the sub-group
// totals, each item combines the total of the earlier sub-groups, and exclusive scans finally shift
// the inclusive result by one work item and apply init once.
template <int SharedMemorySize, bool ExclusiveScan, typename OutType, typename MemoryType,
          typename BinaryOperation>
OutType wg_hiplike_scan(OutType x, BinaryOperation op, MemoryType shrd_mem, OutType init = 0) {

  const __acpp_uint32 sg_lid = __acpp_sscp_get_subgroup_local_id();
  const __acpp_int32 sg_size = __acpp_sscp_get_subgroup_size();

  const __acpp_uint32 subgroup_id = __acpp_sscp_get_subgroup_id();

  const bool last_item_in_sg = sg_lid == static_cast<__acpp_uint32>(sg_size - 1);
  OutType sg_scan_result = sg_inclusive_scan(x, op);

  if (last_item_in_sg) {
    shrd_mem[subgroup_id] = sg_scan_result;
  }
  __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                 __acpp_sscp_memory_order::acq_rel);
  if (subgroup_id == 0) {
    // Each lane reads and writes only its own slot, so there is no cross-item race here.
    shrd_mem[sg_lid] = sg_inclusive_scan(shrd_mem[sg_lid], op);
  }
  __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                 __acpp_sscp_memory_order::acq_rel);

  // Total of all earlier sub-groups (valid for subgroup_id > 0).
  OutType prefix{};
  if (subgroup_id > 0)
    prefix = shrd_mem[subgroup_id - 1];
  const OutType inclusive = subgroup_id > 0 ? op(prefix, sg_scan_result) : sg_scan_result;

  if constexpr (ExclusiveScan) {
    // Shift by one work item: a sub-group collective, executed by every lane.
    const OutType prev_in_sg = __builtin_bit_cast(
        OutType, sg_shift_right(__builtin_bit_cast(typename integer_type<OutType>::type, inclusive), 1));
    if (subgroup_id == 0 && sg_lid == 0)
      return init;
    const OutType prev = sg_lid == 0 ? prefix : prev_in_sg;
    return op(init, prev);
  } else {
    return inclusive;
  }
}

} // namespace hipsycl::libkernel::sscp

#endif
