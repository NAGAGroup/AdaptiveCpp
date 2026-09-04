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
#ifndef HIPSYCL_INORDER_EXECUTOR_HPP
#define HIPSYCL_INORDER_EXECUTOR_HPP

#include <atomic>
#include <future>
#include <memory>
#include <mutex>
#include <vector>

#include "executor.hpp"
#include "hipSYCL/runtime/operations.hpp"
#include "inorder_queue.hpp"

namespace hipsycl {
namespace rt {

/// inorder_executor implements the executor
/// interface on top of inorder_queue objects.
///
/// This class is thread-safe, provided that the underlying
/// inorder_queue is thread-safe.
class inorder_executor : public backend_executor
{
public:
  inorder_executor(std::unique_ptr<inorder_queue> q);

  virtual ~inorder_executor();

  bool is_inorder_queue() const final override;
  bool is_outoforder_queue() const final override;
  bool is_taskgraph() const final override;

  virtual void
  submit_directly(const dag_node_ptr& node, operation *op,
                  const node_list_t &reqs) override;

  inorder_queue* get_queue() const;

  bool can_execute_on_device(const device_id& dev) const override;
  bool is_submitted_by_me(const dag_node_ptr& node) const override;

  result wait();
private:
  /// Issue the operation on the calling thread. Requirements must already
  /// allow this.
  void submit_inline(const dag_node_ptr& node, operation *op,
                     const node_list_t &reqs,
                     const std::shared_ptr<dag_node_event>& deferred_evt);

  /// Run the submission on another thread, once everything it must follow has
  /// been issued. Requirements are waited for rather than enqueued when the
  /// operation may not be issued before they have completed.
  void submit_deferred(const dag_node_ptr& node, operation *op,
                       const node_list_t &reqs, bool wait_for_requirements);

  /// Whether an operation has been accepted but not yet issued, so that
  /// anything submitted now would otherwise reach the queue before it.
  bool has_pending_submission();

  /// Record that this operation has been accepted but not yet issued, and
  /// return the one it must be issued after, if there is one.
  std::shared_ptr<dag_node_event>
  exchange_pending_submission(std::shared_ptr<dag_node_event> evt);

  std::unique_ptr<inorder_queue> _q;
  std::atomic<std::size_t> _num_submitted_operations;

  // Operations are ordered by when they are issued to the queue, so one that
  // is waiting to be issued must be issued before anything that follows it
  // here. The flag is read by every submission but written only by those that
  // defer, so the common path takes no lock.
  std::atomic<bool> _has_pending_submission{false};
  std::shared_ptr<dag_node_event> _pending_submission;
  std::mutex _pending_submission_mutex;

  std::vector<std::future<void>> _deferred_submissions;
  std::mutex _deferred_submissions_mutex;
};

}
}

#endif
