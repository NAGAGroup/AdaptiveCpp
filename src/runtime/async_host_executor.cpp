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
#include <thread>

#include "hipSYCL/runtime/async_host_executor.hpp"
#include "hipSYCL/runtime/dag_node.hpp"
#include "hipSYCL/runtime/operations.hpp"
#include "hipSYCL/runtime/serialization/serialization.hpp"

namespace hipsycl {
namespace rt {

namespace {

class host_operation_dispatcher : public operation_dispatcher {
public:
  virtual ~host_operation_dispatcher() {}

  virtual result dispatch_kernel(kernel_operation *op,
                                 const dag_node_ptr& node) final override {
    return unsupported("kernel");
  }

  virtual result dispatch_memcpy(memcpy_operation *op,
                                 const dag_node_ptr& node) final override {
    return unsupported("memcpy");
  }

  virtual result dispatch_prefetch(prefetch_operation *op,
                                   const dag_node_ptr& node) final override {
    return unsupported("prefetch");
  }

  virtual result dispatch_memset(memset_operation *op,
                                 const dag_node_ptr& node) final override {
    return unsupported("memset");
  }

  virtual result dispatch_async_host(async_host_operation *op,
                                     const dag_node_ptr& node) final override {
    op->run();
    return make_success();
  }

private:
  result unsupported(const std::string &op) const {
    return make_error(__acpp_here(),
                      error_info{"async_host_executor: Cannot run " + op +
                                     " operations",
                                 error_type::invalid_parameter_error});
  }
};

}

async_host_executor::async_host_executor(std::size_t num_threads)
    : _next_worker{0} {
  if(num_threads == 0) {
    num_threads = std::thread::hardware_concurrency();
    if(num_threads == 0)
      num_threads = 1;
  }

  for(std::size_t i = 0; i < num_threads; ++i)
    _workers.push_back(std::make_unique<worker_thread>());
}

async_host_executor::~async_host_executor() {
  for(auto &w : _workers)
    w->halt();
}

worker_thread &async_host_executor::select_worker() {
  // Round-robin: host operations are independent of one another, and a worker
  // may be blocked waiting for the requirements of the operation it holds.
  std::size_t i = _next_worker.fetch_add(1) % _workers.size();
  return *_workers[i];
}

bool async_host_executor::is_submitted_by_me(const dag_node_ptr& node) const {
  if(!node->is_submitted())
    return false;
  return node->get_assigned_executor() == this;
}

void async_host_executor::wait() {
  for(auto &w : _workers)
    w->wait();
}

void async_host_executor::submit_directly(const dag_node_ptr& node,
                                          operation *op,
                                          const node_list_t &reqs) {
  assert(!op->is_requirement());

  if(node->is_submitted())
    return;

  auto evt = std::make_shared<async_host_event>();
  node->mark_submitted(evt);

  std::shared_ptr<dag_node_event> preceding;
  if(op->is_host_operation())
    preceding = static_cast<async_host_operation *>(op)->get_preceding_event();

  node_list_t requirements = reqs;
  select_worker()([node, op, evt, requirements, preceding]() {
    for(const auto &req : requirements) {
      if(req)
        req->wait();
    }

    if(preceding)
      preceding->wait();

    host_operation_dispatcher dispatcher;
    result res = op->dispatch(&dispatcher, node);
    if(!res.is_success())
      register_error(res);

    evt->signal();
  });
}

}
}
