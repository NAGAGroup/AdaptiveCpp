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
#ifndef HIPSYCL_INORDER_QUEUE_HPP
#define HIPSYCL_INORDER_QUEUE_HPP

#include <memory>
#include <string>
#include <functional>

#include "dag_node.hpp"
#include "hints.hpp"
#include "operations.hpp"
#include "error.hpp"
#include "code_object_invoker.hpp"

namespace hipsycl {
namespace rt {

class code_object;

class inorder_queue_status {
public:
  inorder_queue_status() = default;
  inorder_queue_status(bool is_complete)
  : _is_complete{is_complete} {}

  bool is_complete() const {
    return _is_complete;
  }

private:
  bool _is_complete;
};

/// Represents an in-order queue. Implementations of this abstract
/// interface have to be thread-safe.
class inorder_queue
{
public:

  /// Inserts an event into the stream
  virtual std::shared_ptr<dag_node_event> insert_event() = 0;
  virtual std::shared_ptr<dag_node_event> create_queue_completion_event() = 0;

  virtual result submit_memcpy(memcpy_operation&, const dag_node_ptr&) = 0;
  virtual result submit_kernel(kernel_operation&, const dag_node_ptr&) = 0;
  virtual result submit_prefetch(prefetch_operation &, const dag_node_ptr&) = 0;
  virtual result submit_memset(memset_operation&, const dag_node_ptr&) = 0;
  
  /// Causes the queue to wait until an event on another queue has occured.
  /// the other queue must be from the same backend
  virtual result submit_queue_wait_for(const dag_node_ptr& evt) = 0;
  virtual result submit_external_wait_for(const dag_node_ptr& node) = 0;

  /// Whether the operation reads its operands when it is issued rather than
  /// when the queue reaches it, so that submitting it to this queue does not
  /// order it against work the queue has been told to wait for.
  ///
  /// Such an operation must not be issued until its requirements have
  /// completed. Only the backend can answer this: it depends on the backend's
  /// own API and on properties of the operands that only it can query.
  virtual bool needs_completed_requirements(operation &op,
                                            const node_list_t &reqs) const {
    return false;
  }

  /// An event standing in for an operation that has been accepted but not yet
  /// issued. Backends that never defer a submission do not need one.
  virtual std::shared_ptr<dag_node_event> create_deferred_event() {
    return nullptr;
  }

  /// Give a deferred event the event describing the operation, now that it
  /// has been issued.
  virtual void stamp_deferred_event(dag_node_event &deferred,
                                    std::shared_ptr<dag_node_event> actual) {}

  virtual result wait() = 0;

  virtual device_id get_device() const = 0;
  /// Return native type if supported, nullptr otherwise
  virtual void* get_native_type() const = 0;

  virtual result query_status(inorder_queue_status& status) = 0;

  // low-level SSCP submission interface
  virtual result submit_sscp_kernel_from_code_object(hcf_object_id hcf_object,
      std::string_view kernel_name, const rt::hcf_kernel_info *kernel_info,
      const rt::range<3> &num_groups, const rt::range<3> &group_size,
      unsigned local_mem_size, void **args, std::size_t *arg_sizes,
      std::size_t num_args, const kernel_configuration &config) = 0;

  virtual ~inorder_queue(){}

  using kernel_launch_complete_callback_t =
      std::function<void(std::string_view, const code_object *)>;
  void set_kernel_launch_callback(kernel_launch_complete_callback_t cb) {
    _launch_complete_callback = cb;
  }

protected:
  void on_kernel_launch_complete(std::string_view kernel_name,
                                 const code_object *cb) {
    if(_launch_complete_callback)
      _launch_complete_callback(kernel_name, cb);
  }

private:
  kernel_launch_complete_callback_t _launch_complete_callback;
};

}
}

#endif
