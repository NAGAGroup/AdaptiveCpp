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
#ifndef HIPSYCL_ASYNC_HOST_EXECUTOR_HPP
#define HIPSYCL_ASYNC_HOST_EXECUTOR_HPP

#include <atomic>
#include <cstddef>
#include <memory>
#include <vector>

#include "executor.hpp"
#include "generic/async_worker.hpp"
#include "signal_channel.hpp"

namespace hipsycl {
namespace rt {

class async_host_event : public dag_node_event {
public:
  async_host_event() : _signal{std::make_shared<signal_channel>()} {}

  virtual bool is_complete() const override {
    return _signal->has_signalled();
  }

  virtual void wait() override { _signal->wait(); }

  void signal() { _signal->signal(); }

private:
  std::shared_ptr<signal_channel> _signal;
};

/// Runs host operations on threads owned by the runtime, so that they neither
/// depend on a backend being visible nor compete with a backend's device for
/// its execution resources.
class async_host_executor : public backend_executor {
public:
  async_host_executor(std::size_t num_threads = 0);
  virtual ~async_host_executor();

  virtual bool is_inorder_queue() const override { return false; }
  virtual bool is_outoforder_queue() const override { return true; }
  virtual bool is_taskgraph() const override { return false; }
  virtual bool is_backend_queue() const override { return false; }

  virtual void submit_directly(const dag_node_ptr& node, operation *op,
                               const node_list_t &reqs) override;

  virtual bool can_execute_on_device(const device_id& dev) const override {
    return true;
  }

  virtual bool is_submitted_by_me(const dag_node_ptr& node) const override;

  void wait();

private:
  worker_thread &select_worker();

  std::vector<std::unique_ptr<worker_thread>> _workers;
  std::atomic<std::size_t> _next_worker;
};

}
}

#endif
