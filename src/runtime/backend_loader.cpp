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
#include "hipSYCL/runtime/backend_loader.hpp"
#include "hipSYCL/common/config.hpp"
#include "hipSYCL/common/debug.hpp"
#include "hipSYCL/common/dylib_loader.hpp"
#include "hipSYCL/common/filesystem.hpp"
#include "hipSYCL/common/settings.hpp"
#include "hipSYCL/runtime/application.hpp"
#include "hipSYCL/runtime/device_id.hpp"

#include <cassert>

#ifndef _WIN32
#include <dlfcn.h>
#else
#include <windows.h>
#endif

#include HIPSYCL_CXX_FILESYSTEM_HEADER
#include <vector>
#include <string>
namespace fs = HIPSYCL_CXX_FILESYSTEM_NAMESPACE;

namespace {

using namespace hipsycl::common;
bool load_plugin(const std::string &filename, void *&handle_out,
                 std::string &backend_name_out) {
  std::string message = "";
  if (void *handle = load_library(filename, message)) {
    if (void *symbol = get_symbol_from_library(
            handle, "hipsycl_backend_plugin_get_name", message)) {
      auto get_name =
          reinterpret_cast<decltype(&hipsycl_backend_plugin_get_name)>(symbol);

      handle_out = handle;
      backend_name_out = get_name();

      return true;
    } else {
      if (!message.empty()) {
        HIPSYCL_DEBUG_WARNING << "[backend_loader] " << message << std::endl;
        message = "";
      }
      close_library(handle, message);
      if (!message.empty()) {
        HIPSYCL_DEBUG_ERROR << "[backend_loader] " << message << std::endl;
      }
      return false;
    }
  } else {
    if (!message.empty()) {
      HIPSYCL_DEBUG_WARNING << "[backend_loader] " << message << std::endl;
    }
    return false;
  }
}

hipsycl::rt::backend *create_backend(void *plugin_handle) {
  assert(plugin_handle);

  std::string message;
  if (void *symbol = get_symbol_from_library(
          plugin_handle, "hipsycl_backend_plugin_create", message)) {
    auto create_backend_func =
        reinterpret_cast<decltype(&hipsycl_backend_plugin_create)>(symbol);

    return create_backend_func();
  } else if (!message.empty()) {
    HIPSYCL_DEBUG_WARNING << "[backend_loader] " << message << std::endl;
  }
  return nullptr;
}

std::vector<fs::path> get_plugin_search_paths()
{
  std::vector<fs::path> paths;
#ifndef _WIN32
  Dl_info info;
  if (dladdr(reinterpret_cast<void*>(&get_plugin_search_paths), &info)) {
    paths.emplace_back(fs::path{info.dli_fname}.parent_path() / "hipSYCL");
  }
#else
  if(HMODULE handle = GetModuleHandleA(HIPSYCL_RT_LIBRARY_NAME))
  {
    std::vector<char> path_buffer(MAX_PATH);
    while(GetModuleFileNameA(handle, path_buffer.data(), path_buffer.size()) == path_buffer.size())
    {
      path_buffer.resize(path_buffer.size() * 2);
      if(path_buffer.size() >= 1024*1024) // 1MB paths? sure. I think it's time to give up...
        break;
    }
    AddDllDirectory(fs::path{path_buffer.data()}.parent_path().c_str());
    paths.emplace_back(fs::path{path_buffer.data()}.parent_path() / "hipSYCL");
  }
#endif

  if(auto lib_dir = hipsycl::common::filesystem::get_lib_directory(); !lib_dir.empty()) {
#ifdef _WIN32
    AddDllDirectory(fs::path(lib_dir).c_str());
#endif
    paths.emplace_back(fs::path(lib_dir) / "hipSYCL");
  }

#ifdef _WIN32
  // Shipped vendors' DLLs (and, in toolchain mode, libomp.dll) do not
  // necessarily live beside this library or under the install prefix - the
  // app config says where (config/windows/common/app/*.cfg's
  // ACPP_<VENDOR>_DLL_DIR rows), so each is registered here too, before any
  // backend plugin - and the vendor DLLs it transitively loads - is opened
  // below.
  for(const char* setting_name :
      {"cuda_dll_dir", "hip_dll_dir", "ocl_dll_dir", "ze_dll_dir", "libomp_dll_dir"}) {
    std::string dll_dir;
    if(hipsycl::common::settings::try_retrieve_settings_variable(setting_name, dll_dir) &&
       !dll_dir.empty() && fs::is_directory(dll_dir)) {
      AddDllDirectory(fs::path{dll_dir}.c_str());
    }
  }
#endif

  return paths;
}

bool is_plugin_active(const std::string& name)
{
  auto backends_active = hipsycl::rt::application::get_settings().get<hipsycl::rt::setting::visibility_mask>();
  if(backends_active.empty())
    return true;
  if(name == "omp") // we always need a cpu backend
    return true;

  hipsycl::rt::backend_id id;
  if(name == "cuda") {
    id = hipsycl::rt::backend_id::cuda;
  } else if(name == "hip") {
    id = hipsycl::rt::backend_id::hip;
  } else if(name == "ze") {
    id = hipsycl::rt::backend_id::level_zero;
  } else if(name == "ocl") {
    id = hipsycl::rt::backend_id::ocl;
  } else if(name == "metal") {
    id = hipsycl::rt::backend_id::metal;
  } else if(name == "vk") {
    id = hipsycl::rt::backend_id::vk;
  }
  return backends_active.find(id) != backends_active.cend();
}

}

namespace hipsycl {
namespace rt {

void backend_loader::query_backends() {
  std::vector<fs::path> backend_lib_paths = get_plugin_search_paths();
  
#ifdef __APPLE__
  std::string shared_lib_extension = ".dylib";
#elif defined(_WIN32)
  std::string shared_lib_extension = ".dll";
#else
  std::string shared_lib_extension = ".so";
#endif

  for(const fs::path& backend_lib_path : backend_lib_paths) {
    if(!fs::is_directory(backend_lib_path)) {
      HIPSYCL_DEBUG_INFO << "backend_loader: Backend lib search path candidate does not exists: "
                        << backend_lib_path << std::endl;
      continue;
    }

    HIPSYCL_DEBUG_INFO << "backend_loader: Searching path for backend libs: '"
                      << backend_lib_path << "'" << std::endl;

    for (const fs::directory_entry &entry :
        fs::directory_iterator(backend_lib_path)) {

      if(fs::is_regular_file(entry.status())){
        auto p = entry.path();
        if (p.extension().string() == shared_lib_extension) {
          std::string backend_name;
          void *handle;
          if (load_plugin(p.string(), handle, backend_name)) {
            if(!has_backend(backend_name) && is_plugin_active(backend_name)){
              HIPSYCL_DEBUG_INFO << "backend_loader: Successfully opened plugin: " << p
                                << " for backend '" << backend_name << "'"
                                << std::endl;
              _handles.emplace_back(std::make_pair(backend_name, handle));
            } else {
              std::string message = "";
              close_library(handle, message);
              if(!message.empty()) {
                HIPSYCL_DEBUG_ERROR << "[backend_loader] " << message << std::endl;
              }
            }
          }
        }
      }
    }
  }
}

backend_loader::~backend_loader() {
  for (auto &handle : _handles) {
    assert(handle.second);

    std::string message;
    close_library(handle.second, message);
    if (!message.empty()) {
      HIPSYCL_DEBUG_ERROR << "[backend_loader] " << message << std::endl;
    }
  }
}

std::size_t backend_loader::get_num_backends() const { return _handles.size(); }

std::string backend_loader::get_backend_name(std::size_t index) const {
  assert(index < _handles.size());
  return _handles[index].first;
}

bool backend_loader::has_backend(const std::string &name) const {
  for (const auto &h : _handles) {
    if (h.first == name)
      return true;
  }

  return false;
}

backend *backend_loader::create(std::size_t index) const {
  assert(index < _handles.size());
  
  return create_backend(_handles[index].second);
}

backend *backend_loader::create(const std::string &name) const {
  
  for (std::size_t i = 0; i < _handles.size(); ++i) {
    if (_handles[i].first == name)
      return create(i);
  }

  return nullptr;
}

} // namespace rt
} // namespace hipsycl
