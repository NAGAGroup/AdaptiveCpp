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

template <int SharedMemorySize, bool ExclusiveScan, typename OutType, typename MemoryType,
          typename BinaryOperation>
OutType wg_hiplike_scan(OutType x, BinaryOperation op, MemoryType shrd_mem, OutType init = 0) {

  const __acpp_uint32 sg_lid = __acpp_sscp_get_subgroup_local_id();
  const __acpp_int32 sg_size = __acpp_sscp_get_subgroup_size();

  const __acpp_uint32 subgroup_id = __acpp_sscp_get_subgroup_id();

  const bool last_item_in_sg = sg_lid == static_cast<__acpp_uint32>(sg_size - 1);
  OutType sg_scan_result;
  if constexpr (ExclusiveScan) {
    sg_scan_result = sg_exclusive_scan(x, op, init);
  } else {
    sg_scan_result = sg_inclusive_scan(x, op);
  }

  if (last_item_in_sg) {
    if constexpr (ExclusiveScan) {
      shrd_mem[subgroup_id] = op(sg_scan_result, x);
    } else {
      shrd_mem[subgroup_id] = sg_scan_result;
    }
  }
  __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                 __acpp_sscp_memory_order::acq_rel);
  if (subgroup_id == 0) {
    shrd_mem[sg_lid] = sg_inclusive_scan(shrd_mem[sg_lid], op);
  }
  __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                 __acpp_sscp_memory_order::acq_rel);
  return subgroup_id > 0 ? op(shrd_mem[subgroup_id - 1], sg_scan_result) : sg_scan_result;
}

} // namespace hipsycl::libkernel::sscp

#endif
