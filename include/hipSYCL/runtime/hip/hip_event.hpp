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
#ifndef HIPSYCL_HIP_EVENT_HPP
#define HIPSYCL_HIP_EVENT_HPP

#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>

#include "../inorder_queue_event.hpp"

struct ihipEvent_t;

namespace hipsycl {
namespace rt {

class hip_event_pool;
class hip_node_event : public inorder_queue_event<ihipEvent_t*>
{
public:
  using backend_event_type = ihipEvent_t*;
  /// \param evt Must have been properly initialized and recorded.
  /// \param pool the pool managing the event. If not null, the destructor
  /// will return the event to the pool.
  hip_node_event(device_id dev, backend_event_type evt, hip_event_pool* pool = nullptr);

  ~hip_node_event();

  virtual bool is_complete() const override;
  virtual void wait() override;

  ihipEvent_t* get_event() const;
  device_id get_device() const;

  virtual backend_event_type request_backend_event() override;
private:
  device_id _dev;
  backend_event_type _evt;
  hip_event_pool* _pool;
};

/// Event for an operation that has not been submitted to the backend yet.
///
/// Operations that must have their dependencies satisfied before they are
/// issued are submitted from another thread, so there is no backend event to
/// describe them at the time the node is created. This event stands in until
/// that thread has issued the operation, at which point it adopts the event
/// that describes it. Waiting on the operation therefore waits for the
/// submission and then for the operation itself, and requesting the backend
/// event blocks until one exists.
///
/// Stamping also signals that the operation has reached the backend queue, so
/// that submissions which rely on enqueue order can wait for it.
class hip_deferred_event : public inorder_queue_event<ihipEvent_t*> {
public:
  using backend_event_type = ihipEvent_t*;

  virtual bool is_complete() const override;
  virtual void wait() override;

  virtual bool is_submitted() const override { return _is_stamped; }
  virtual void wait_for_submission() const override;

  backend_event_type request_backend_event() override;

  /// Adopt the event describing the operation, which has now been issued.
  /// A null event marks an operation that was never issued, so that anything
  /// waiting for it is released rather than left waiting forever.
  void stamp(std::shared_ptr<hip_node_event> evt);
private:
  std::atomic<bool> _is_stamped{false};
  std::shared_ptr<hip_node_event> _evt;
  mutable std::mutex _mutex;
  mutable std::condition_variable _submitted;
};

}
}


#endif