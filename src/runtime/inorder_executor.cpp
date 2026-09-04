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
#include <algorithm>
#include <cassert>
#include <chrono>

#include "hipSYCL/runtime/inorder_executor.hpp"
#include "hipSYCL/runtime/inorder_queue.hpp"
#include "hipSYCL/runtime/operations.hpp"
#include "hipSYCL/runtime/serialization/serialization.hpp"

namespace hipsycl {
namespace rt {

namespace {

class queue_operation_dispatcher : public operation_dispatcher
{
public:
  queue_operation_dispatcher(inorder_queue* q)
  : _queue{q}
  {}

  virtual ~queue_operation_dispatcher(){}

  virtual result dispatch_kernel(kernel_operation *op,
                                 const dag_node_ptr& node) final override {

    return _queue->submit_kernel(*op, node);
  }

  virtual result dispatch_memcpy(memcpy_operation *op,
                                 const dag_node_ptr& node) final override {
    return _queue->submit_memcpy(*op, node);
  }

  virtual result dispatch_prefetch(prefetch_operation *op,
                                   const dag_node_ptr& node) final override {
    return _queue->submit_prefetch(*op, node);
  }

  virtual result dispatch_memset(memset_operation *op,
                                 const dag_node_ptr& node) final override {
    return _queue->submit_memset(*op, node);
  }

private:
  inorder_queue* _queue;
};

std::size_t get_maximum_execution_index_for_lane(const node_list_t &nodes,
                                                 inorder_queue *lane) {
  std::size_t index = 0;
  for (const auto &node : nodes) {
    if (node->is_submitted() &&
        node->get_assigned_device().get_backend() ==
            lane->get_device().get_backend() &&
        node->get_assigned_execution_lane() == lane) {
      if(node->get_assigned_execution_index() > index)
        index = node->get_assigned_execution_index();
    }
  }
  return index;
}

} // anonymous namespace

inorder_executor::inorder_executor(std::unique_ptr<inorder_queue> q)
: _q{std::move(q)}, _num_submitted_operations{0} {}

inorder_executor::~inorder_executor(){}

bool inorder_executor::is_inorder_queue() const {
  return true;
}

bool inorder_executor::is_outoforder_queue() const {
  return false;
}

bool inorder_executor::is_taskgraph() const {
  return false;
}

bool inorder_executor::has_pending_submission() {
  if(!_has_pending_submission)
    return false;

  std::lock_guard<std::mutex> lock{_pending_submission_mutex};
  if(!_pending_submission)
    return false;
  // Whoever finds it issued clears it, so that submissions go back to being
  // issued on the calling thread.
  if(_pending_submission->is_submitted()) {
    _pending_submission = nullptr;
    _has_pending_submission = false;
    return false;
  }
  return true;
}

std::shared_ptr<dag_node_event> inorder_executor::exchange_pending_submission(
    std::shared_ptr<dag_node_event> evt) {
  // Reading the operation to follow and recording this one must happen
  // together, or two submissions could follow the same operation and one of
  // them would be left with nothing ordering it.
  std::lock_guard<std::mutex> lock{_pending_submission_mutex};

  std::shared_ptr<dag_node_event> predecessor = _pending_submission;
  if(predecessor && predecessor->is_submitted())
    predecessor = nullptr;

  _pending_submission = std::move(evt);
  _has_pending_submission = true;

  return predecessor;
}

void inorder_executor::submit_deferred(const dag_node_ptr& node, operation *op,
                                       const node_list_t &reqs,
                                       bool wait_for_requirements) {
  auto deferred_evt = _q->create_deferred_event();
  if(!deferred_evt) {
    register_error(__acpp_here(),
                   error_info{"inorder_executor: Backend requires a deferred "
                              "submission but provides no deferred event"});
    node->cancel();
    return;
  }

  auto predecessor = exchange_pending_submission(deferred_evt);

  // The node carries an event from the outset, so that waiting on it waits
  // for the submission and then for the operation.
  node->mark_submitted(deferred_evt);

  {
    std::lock_guard<std::mutex> lock{_deferred_submissions_mutex};
    _deferred_submissions.erase(
        std::remove_if(_deferred_submissions.begin(),
                       _deferred_submissions.end(),
                       [](const std::future<void> &f) {
                         return f.wait_for(std::chrono::seconds(0)) ==
                                std::future_status::ready;
                       }),
        _deferred_submissions.end());

    _deferred_submissions.push_back(std::async(
        std::launch::async,
        [this, node, op, reqs, predecessor, deferred_evt,
         wait_for_requirements]() {
          if(predecessor)
            predecessor->wait_for_submission();

          if(wait_for_requirements) {
            for(const auto &req : reqs) {
              if(!req->is_known_complete())
                req->wait();
            }
          }

          submit_inline(node, op, wait_for_requirements ? node_list_t{} : reqs,
                        deferred_evt);

          // A submission that failed never reaches the queue; release anyone
          // waiting for it rather than leaving them waiting forever.
          if(!deferred_evt->is_submitted())
            _q->stamp_deferred_event(*deferred_evt, nullptr);
        }));
  }
}

void inorder_executor::submit_directly(const dag_node_ptr& node, operation *op,
                                       const node_list_t &reqs) {
  
  HIPSYCL_DEBUG_INFO << "inorder_executor: Processing node " << node.get()
	  << " with " << reqs.size() << " non-virtual requirement(s) and "
	  << node->get_requirements().size() << " direct requirement(s)." << std::endl;

  assert(!op->is_requirement());

  if (node->is_submitted())
    return;

  node->assign_to_execution_lane(_q.get());

  node->assign_execution_index(++_num_submitted_operations);

  // An operation that reads its operands when it is issued cannot be ordered
  // against its requirements by anything submitted to the queue, so it is
  // issued from another thread once they have completed.
  if(_q->needs_completed_requirements(*op, reqs)) {
    submit_deferred(node, op, reqs, true);
    return;
  }

  // Anything that has been accepted but not issued must reach the queue
  // first, and so must anything this operation depends on.
  bool must_follow_unsubmitted = has_pending_submission();
  if(!must_follow_unsubmitted) {
    for(const auto &req : reqs) {
      if(!req->is_known_complete() && req->get_event() &&
         !req->get_event()->is_submitted()) {
        must_follow_unsubmitted = true;
        break;
      }
    }
  }
  if(must_follow_unsubmitted) {
    submit_deferred(node, op, reqs, false);
    return;
  }

  submit_inline(node, op, reqs, nullptr);
}

void inorder_executor::submit_inline(
    const dag_node_ptr& node, operation *op, const node_list_t &reqs,
    const std::shared_ptr<dag_node_event>& deferred_evt) {

  // Submit synchronization mechanisms
  result res;
  for (auto req : reqs) {
    // The scheduler should not hand us virtual requirements
    assert(!req->is_virtual());
    assert(req->is_submitted());

    // Nothing to do if we have to synchronize with
    // an operation that is already known to have completed
    if(!req->is_known_complete()) {
      if (req->get_assigned_device().get_backend() !=
          _q->get_device().get_backend()) {
        HIPSYCL_DEBUG_INFO
            << " --> Synchronizes with external node: " << req
            << std::endl;
        res = _q->submit_external_wait_for(req);
      } else {
        if (req->get_assigned_execution_lane() == _q.get()) {
          HIPSYCL_DEBUG_INFO
            << " --> (Skipping same-lane synchronization with node: " << req
            << ")" << std::endl;
          // Nothing to synchronize, the requirement was enqueued on the same
          // inorder queue and will therefore be executed before
          // the new node
        } else {
          assert(req->get_event());

          HIPSYCL_DEBUG_INFO << " --> Synchronizes with other queue for node: "
                            << req
                            << std::endl;
          // We only need to actually synchronize with the lane if this req
          // is the operation that has been submitted *last* to the lane
          // out of all requirements in reqs.
          // (Follows from execution lanes being in-order queues)
          //
          // Find the maximum execution index out of all our requirements.
          // Since the execution index is incremented after each submission,
          // this allows us to identify the requirement that was submitted last.
          inorder_queue *req_q = static_cast<inorder_queue *>(
              req->get_assigned_execution_lane());
          std::size_t maximum_execution_index =
              get_maximum_execution_index_for_lane(reqs, req_q);
          
          if(req->get_assigned_execution_index() != maximum_execution_index) {
            HIPSYCL_DEBUG_INFO
                << "  --> (Skipping unnecessary synchronization; another "
                   "requirement follows in the same inorder queue)"
                << std::endl;
          } else {
            res = _q->submit_queue_wait_for(req);
          }
        }
      }
      if (!res.is_success()) {
        register_error(res);
        node->cancel();
        return;
      }
    }
  }

  HIPSYCL_DEBUG_INFO
      << "inorder_executor: Dispatching to lane " << _q.get() << ": "
      << dump(op) << std::endl;
  
  queue_operation_dispatcher dispatcher{_q.get()};
  res = op->dispatch(&dispatcher, node);
  if (!res.is_success()) {
    register_error(res);
    node->cancel();
    return;
  }

  std::shared_ptr<dag_node_event> evt;
  if (node->get_execution_hints()
          .has_hint<hints::coarse_grained_synchronization>()) {
    evt = _q->create_queue_completion_event();
  } else {
    evt = _q->insert_event();
  }

  if(deferred_evt)
    _q->stamp_deferred_event(*deferred_evt, std::move(evt));
  else
    node->mark_submitted(std::move(evt));
}

inorder_queue* inorder_executor::get_queue() const {
  return _q.get();
}

bool inorder_executor::can_execute_on_device(const device_id& dev) const {
  return _q->get_device() == dev;
}

bool inorder_executor::is_submitted_by_me(const dag_node_ptr& node) const {
  if(!node->is_submitted())
    return false;
  return node->get_assigned_executor() == this;
}

result inorder_executor::wait() {
  return _q->wait();
}

}
}