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

#ifndef HIPSYCL_SSCP_DETAIL_REDUCTION_BUILTINS_HPP
#define HIPSYCL_SSCP_DETAIL_REDUCTION_BUILTINS_HPP

#include "../core_typed.hpp"
#include "../subgroup.hpp"
#include "broadcast.hpp"
#include "shuffle.hpp"
#include "utils.hpp"

namespace hipsycl::libkernel::sscp {

namespace {
template <typename OutType, typename BinaryOperation>
OutType sg_reduce_impl(OutType x, BinaryOperation binary_op, __acpp_int32 active_threads) {
  const __acpp_uint32 lrange = __acpp_sscp_get_subgroup_max_size();
  const __acpp_uint32 lid = __acpp_sscp_get_subgroup_local_id();
  const __acpp_uint64 subgroup_size = active_threads;
  auto local_x = x;
  for (__acpp_int32 i = lrange / 2; i > 0; i /= 2) {
    auto other_x = __builtin_bit_cast(
        OutType,
        sg_select(__builtin_bit_cast(typename integer_type<OutType>::type, local_x), lid + i));
    if (lid + i < subgroup_size)
      local_x = binary_op(local_x, other_x);
  }
  return __builtin_bit_cast(
      OutType, sg_select(__builtin_bit_cast(typename integer_type<OutType>::type, local_x), 0));
}
} // namespace

template <__acpp_sscp_algorithm_op binary_op, typename OutType> OutType sg_reduce(OutType x) {
  using op = typename get_op<binary_op>::type;
  const __acpp_uint32 lrange = __acpp_sscp_get_subgroup_size();
  return sg_reduce_impl(x, op{}, lrange);
}

template <__acpp_uint64 shmem_array_length, typename OutType, typename MemoryType,
          typename BinaryOperation>
OutType wg_reduce(OutType x, BinaryOperation op, MemoryType *shrd_mem) {

  const __acpp_uint32 wg_lid = __acpp_sscp_typed_get_local_linear_id<3, int>();
  const __acpp_int32 sg_size = __acpp_sscp_get_subgroup_size();
  const __acpp_uint32 sg_lid = __acpp_sscp_get_subgroup_local_id();
  // The runtime decides how work-items form sub-groups: Intel's CPU OpenCL
  // runtime gives a 2-D 5x5 group one sub-group per row, so
  // wg_lid / max_sub_group_size is not the sub-group id, and the number of
  // sub-groups is not ceil(wg_size / max_sub_group_size). Ask the backend.
  const __acpp_uint32 subgroup_id = __acpp_sscp_get_subgroup_id();
  const __acpp_uint32 num_subgroups = __acpp_sscp_get_num_subgroups();
  // The int32 sub-group size is exact through any MemoryType for sizes <= 64.
  const __acpp_int32 first_sg_size = wg_broadcast(0, sg_size, &shrd_mem[0]);

  OutType local_reduce_result = sg_reduce_impl(x, op, sg_size);

  // One partial per sub-group, written by its lane 0 only.
  if (sg_lid == 0 && subgroup_id < shmem_array_length) {
    shrd_mem[subgroup_id] = local_reduce_result;
  }
  __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                 __acpp_sscp_memory_order::acq_rel);

  for (__acpp_uint32 i = shmem_array_length; i < num_subgroups; i += shmem_array_length) {
    if (sg_lid == 0 && subgroup_id >= i && subgroup_id < i + shmem_array_length) {
      shrd_mem[subgroup_id % shmem_array_length] =
          op(local_reduce_result, shrd_mem[subgroup_id % shmem_array_length]);
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
  }

  // Halve the partials in shared memory until they fit into one sub-group.
  // elements_in_shmem is uniform across the work-group, so every work-item
  // reaches every barrier.
  __acpp_uint32 elements_in_shmem =
      num_subgroups < shmem_array_length ? num_subgroups : shmem_array_length;
  // Bound of at least 1: with a bound of 0 (a bogus sub-group size) the halving would never
  // reach it, since half stays 1 for one element, and the loop would not terminate. With
  // stop == 1 the loop ends with the combined partial in shrd_mem[0], and the first sub-group
  // below then reduces exactly that single element.
  const __acpp_uint32 stop =
      first_sg_size > 1 ? static_cast<__acpp_uint32>(first_sg_size) : 1;
  while (elements_in_shmem > stop) {
    const __acpp_uint32 half = (elements_in_shmem + 1) / 2;
    if (wg_lid < elements_in_shmem - half) {
      shrd_mem[wg_lid] = op(shrd_mem[wg_lid + half], shrd_mem[wg_lid]);
    }
    __acpp_sscp_work_group_barrier(__acpp_sscp_memory_scope::work_group,
                                   __acpp_sscp_memory_order::acq_rel);
    elements_in_shmem = half;
  }

  // The first sub-group reduces the remaining partials.
  if (subgroup_id == 0) {
    if (sg_lid < elements_in_shmem)
      local_reduce_result = shrd_mem[sg_lid];
    local_reduce_result =
        sg_reduce_impl(local_reduce_result, op, static_cast<__acpp_int32>(elements_in_shmem));
  }

  // Do a final broadcast
  // shrd_mem is MemoryType == OutType on every backend (host, ptx, amdgpu,
  // spirv, clspv, metal). Broadcasting the integer bit pattern through
  // float-typed memory value-converted it (int -> float -> int) and dropped
  // the low mantissa bits (~7 for f32, ~8 for f64), so broadcast the value
  // itself, which is a plain copy.
  local_reduce_result = wg_broadcast(0, local_reduce_result, &shrd_mem[0]);
  return local_reduce_result;
}

} // namespace hipsycl::libkernel::sscp

#endif
