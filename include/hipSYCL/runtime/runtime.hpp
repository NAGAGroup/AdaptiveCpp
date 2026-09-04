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
#ifndef HIPSYCL_RUNTIME_HPP
#define HIPSYCL_RUNTIME_HPP

#include "async_host_executor.hpp"
#include "dag_manager.hpp"
#include "backend.hpp"
#include "settings.hpp"

#include <memory>
#include <iostream>

namespace hipsycl {
namespace rt {

class runtime
{
public:

  runtime();

  ~runtime();

  dag_manager& dag()
  { return _dag_manager; }

  const dag_manager& dag() const
  { return _dag_manager; }

  backend_manager &backends() { return _backends; }

  const backend_manager &backends() const { return _backends; }

  async_host_executor &async_host() { return _async_host_executor; }

  const async_host_executor &async_host() const { return _async_host_executor; }

private:
  // !! Attention: order is important, as backends have to be still present,
  // when the dag_manager is destructed!
  backend_manager _backends;
  async_host_executor _async_host_executor;
  dag_manager _dag_manager;
};



}
}


#endif
