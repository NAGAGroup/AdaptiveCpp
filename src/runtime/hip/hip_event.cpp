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
#include "hipSYCL/runtime/hip/hip_event.hpp"
#include "hipSYCL/runtime/hip/hip_target.hpp"
#include "hipSYCL/runtime/hip/hip_event_pool.hpp"
#include "hipSYCL/runtime/error.hpp"

namespace hipsycl {
namespace rt {


hip_node_event::hip_node_event(device_id dev, hipEvent_t evt, hip_event_pool* pool)
: _dev{dev}, _evt{evt}, _pool{pool}
{}

hip_node_event::~hip_node_event() {
  if(_pool) {
    _pool->release_event(_evt);
  }
}

bool hip_node_event::is_complete() const
{
  hipError_t err = hipEventQuery(_evt);
  if (err != hipErrorNotReady && err != hipSuccess) {
    register_error(__acpp_here(),
                   error_info{"hip_node_event: Couldn't query event status",
                              error_code{"HIP", err}});
  }
  return err == hipSuccess;
}

void hip_node_event::wait()
{
  auto err = hipEventSynchronize(_evt);
  if (err != hipSuccess) {
    register_error(__acpp_here(),
                   error_info{"hip_node_event: hipEventSynchronize() failed",
                              error_code{"HIP", err}});
  }
}

hipEvent_t hip_node_event::get_event() const
{
  return _evt;
}

device_id hip_node_event::get_device() const
{
  return _dev;
}

ihipEvent_t* hip_node_event::request_backend_event() {
  return get_event();
}

void hip_deferred_event::stamp(std::shared_ptr<hip_node_event> evt) {
  {
    std::lock_guard<std::mutex> lock{_mutex};
    _evt = std::move(evt);
    _is_stamped = true;
  }
  _submitted.notify_all();
}

void hip_deferred_event::wait_for_submission() const {
  if(_is_stamped)
    return;

  std::unique_lock<std::mutex> lock{_mutex};
  _submitted.wait(lock, [this]{ return _is_stamped.load(); });
}

bool hip_deferred_event::is_complete() const {
  if(!_is_stamped)
    return false;
  return _evt ? _evt->is_complete() : true;
}

void hip_deferred_event::wait() {
  wait_for_submission();
  if(_evt)
    _evt->wait();
}

hip_deferred_event::backend_event_type
hip_deferred_event::request_backend_event() {
  wait_for_submission();
  return _evt ? _evt->request_backend_event() : nullptr;
}

}
}
