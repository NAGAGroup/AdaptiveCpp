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

#include "hipSYCL/compiler/llvm-to-backend/Utils.hpp"
#include "hipSYCL/common/filesystem.hpp"
#include "hipSYCL/common/settings.hpp"

#include <llvm/Support/Program.h>

#ifdef _WIN32
#include <llvm/Support/FileSystem.h>
#endif
#ifdef __linux__
#include <dlfcn.h>
#include <link.h>
#endif

namespace hipsycl {
namespace compiler {

namespace {

std::string getRedistributablePackagePath() {
  const auto install_dir = common::filesystem::get_lib_directory();
  return common::filesystem::join_path(install_dir,
                                       std::vector<std::string>{"hipSYCL", "ext"});
}

std::string getLLVMRedistributablePackagePath() {
  std::string RedistPkg = getRedistributablePackagePath();
  return common::filesystem::join_path(RedistPkg, "llvm");
}

}

std::string getClangPath() {
  static std::string path;
  if(!path.empty())
    return path;

  // "clang" -> ACPP_CLANG in the installed app config
  // (config/linux/common/app/hip.cfg - HIP's JIT, not core.cfg); the bare
  // name below is only the last-resort fallback, resolved via PATH by
  // whoever execs it.
  if(!common::settings::try_retrieve_settings_variable("clang", path) || path.empty())
    path = "clang++";

  return path;
}

std::string getLLCPath() {
  static std::string path;
  if(!path.empty())
    return path;
  
  std::string llvm_redistributable_path = getLLVMRedistributablePackagePath();
  std::string llc_redistributable_path = common::filesystem::join_path(
      llvm_redistributable_path, std::vector<std::string>{"bin", ACPP_LLC_NAME});

  if(common::filesystem::exists(llc_redistributable_path)) {
    path = llc_redistributable_path;
  } else if(!common::settings::try_retrieve_settings_variable("llc", path) || path.empty()) {
    // "llc" -> ACPP_LLC in the installed app config; the bare name is only
    // the last-resort fallback, resolved via PATH by whoever execs it.
    path = ACPP_LLC_NAME;
  }

  return path;
}

std::string getLLDPath() {
  static std::string path;
  if(!path.empty())
    return path;
  
  std::string llvm_redistributable_path = getLLVMRedistributablePackagePath();
  std::string lld_redistributable_path = common::filesystem::join_path(
      llvm_redistributable_path, std::vector<std::string>{"bin", ACPP_LLD_NAME});

  if(common::filesystem::exists(lld_redistributable_path)) {
    path = lld_redistributable_path;
  } else if(!common::settings::try_retrieve_settings_variable("lld", path) || path.empty()) {
    // "lld" -> ACPP_LLD in the installed app config; the bare name is only
    // the last-resort fallback, resolved via PATH by whoever execs it.
    path = ACPP_LLD_NAME;
  }

  return path;
}

std::string getOptPath() {
  static std::string path;
  if(!path.empty())
    return path;
  
  std::string llvm_redistributable_path = getLLVMRedistributablePackagePath();
  std::string opt_redistributable_path = common::filesystem::join_path(
      llvm_redistributable_path, std::vector<std::string>{"bin", ACPP_OPT_NAME});

  if(common::filesystem::exists(opt_redistributable_path)) {
    path = opt_redistributable_path;
  } else if(!common::settings::try_retrieve_settings_variable("opt", path) || path.empty()) {
    // "opt" -> ACPP_OPT in the installed app config; the bare name is only
    // the last-resort fallback, resolved via PATH by whoever execs it.
    path = ACPP_OPT_NAME;
  }

  return path;
}

std::string getLibSleefDir() {
  static std::string path;
  if (!path.empty())
    return path;

  common::settings::try_retrieve_settings_variable("sleef_dir", path);
  return path;
}

std::string getLibAmathDir() {
  static std::string path;
  if (!path.empty())
    return path;

  common::settings::try_retrieve_settings_variable("amath_dir", path);
  return path;
}

std::string getLibSvmlDir() {
  static std::string path;
  if (!path.empty())
    return path;

  common::settings::try_retrieve_settings_variable("svml_dir", path);
  return path;
}

std::string getLibMvecDir() {
  static std::string path;
  if (!path.empty())
    return path;

#if defined(__linux__)
  // libmvec is part of glibc, so the only correct copy is the one the dynamic
  // loader resolves for this process: it must match the libc the process is
  // running against. That process is the application being JIT-compiled, not
  // the build, so asking the loader is the only lookup that can be right.
  //
  // Deliberately not consulted: a copy redistributed beside our own libraries,
  // and the path find_library() reported when AdaptiveCpp was built. Either
  // can name a libmvec built against a different glibc than the one loaded
  // here, and neither can be checked from this side.
  if (void *handle = dlopen("libmvec.so.1", RTLD_LAZY | RTLD_LOCAL)) {
    link_map *map = nullptr;
    if (dlinfo(handle, RTLD_DI_LINKMAP, &map) == 0 && map && map->l_name &&
        map->l_name[0] != '\0') {
      std::string p{map->l_name};
      auto pos = p.find_last_of('/');
      if (pos != std::string::npos && pos > 0)
        path = p.substr(0, pos);
    }
    dlclose(handle);
  }
#endif

  return path;
}

std::string getBitcodePath() {
#ifndef _WIN32
  return common::filesystem::join_path(common::filesystem::get_lib_directory(),
                                    std::vector<std::string>{"hipSYCL", "bitcode"});
#else
  static std::string bitcode_dir;
  if(bitcode_dir.empty()) {
    std::vector<std::string> candidates;
    // On Windows, lib_dir might be either bin/ or lib/ since libraries there might
    // be put in bin/ directory.
    std::string lib_dir = common::filesystem::get_lib_directory();
    candidates.emplace_back(lib_dir);
    candidates.emplace_back(common::filesystem::join_path(lib_dir,
      std::vector<std::string>{"..", "bin"}));
    candidates.emplace_back(common::filesystem::join_path(lib_dir,
      std::vector<std::string>{"..", "lib"}));
    for(const auto& candidate_root : candidates) {
      std::string candidate_bitcode_dir = common::filesystem::join_path(
        candidate_root, std::vector<std::string>{"hipSYCL", "bitcode"});
      if(common::filesystem::exists(candidate_bitcode_dir)) {
        std::error_code error;
        auto file_list = common::filesystem::list_regular_files(candidate_bitcode_dir, error);

        auto includes_bitcode_files = [](const std::vector<std::string>& filenames){
          for(const auto& f : filenames) {
            if(f.find(".bc") != std::string::npos)
              return true;
          }
          return false;
        };

        if(includes_bitcode_files(file_list)) {
          bitcode_dir = candidate_bitcode_dir;
          return bitcode_dir;
        }
      }
    }
    
  }
  return bitcode_dir;
#endif  
}

#if LLVM_VERSION_MAJOR < 16
int executeAndWait(
    llvm::StringRef Program,
    llvm::ArrayRef<llvm::StringRef> Args,
    llvm::Optional<llvm::ArrayRef<llvm::StringRef>> Env,
    llvm::ArrayRef<llvm::Optional<llvm::StringRef>> Redirects) {
  return llvm::sys::ExecuteAndWait(Program, Args, Env, Redirects);
}
#else
int executeAndWait(
    llvm::StringRef Program,
    llvm::ArrayRef<llvm::StringRef> Args,
    std::optional<llvm::ArrayRef<llvm::StringRef>> Env,
    llvm::ArrayRef<std::optional<llvm::StringRef>> Redirects) {
#if !defined(_WIN32) || LLVM_VERSION_MAJOR < 19
  return llvm::sys::ExecuteAndWait(Program, Args, Env, Redirects);
#else
  std::string ErrMsg;
  bool ExecutionFailed = false;

  llvm::SmallVector<std::optional<llvm::StringRef>, 3> ActualRedirects;
  llvm::SmallString<128> StdoutFile;
  llvm::SmallString<128> StderrFile;

  bool CaptureOutput = Redirects.empty();

  if(CaptureOutput) {
    if(auto E = llvm::sys::fs::createTemporaryFile(
           "acpp-tool-stdout", "txt", StdoutFile, llvm::sys::fs::OF_None))
      return -1;

    if(auto E = llvm::sys::fs::createTemporaryFile(
           "acpp-tool-stderr", "txt", StderrFile, llvm::sys::fs::OF_None)) {
      llvm::sys::fs::remove(StdoutFile);
      return -1;
    }

    ActualRedirects.push_back(llvm::StringRef{}); // stdin -> NUL
    ActualRedirects.push_back(StdoutFile.str());  // stdout -> temp file
    ActualRedirects.push_back(StderrFile.str());  // stderr -> temp file

    Redirects = ActualRedirects;
  }

  auto cleanup = [&]() {
    if(CaptureOutput) {
      auto Err0 = llvm::sys::fs::remove(StdoutFile);
      auto Err1 = llvm::sys::fs::remove(StderrFile);
    }
  };

  auto ProcessInfo =
      llvm::sys::ExecuteNoWait(Program, Args, Env, Redirects,
                               0, &ErrMsg, &ExecutionFailed, nullptr, true);

  if(ExecutionFailed) {
    cleanup();
    return -1;
  }

  auto Result = llvm::sys::Wait(ProcessInfo, std::nullopt);

  if(CaptureOutput) {
    if(auto StdoutBuffer = llvm::MemoryBuffer::getFile(StdoutFile))
      llvm::outs() << StdoutBuffer.get()->getBuffer();

    if(auto StderrBuffer = llvm::MemoryBuffer::getFile(StderrFile))
      llvm::errs() << StderrBuffer.get()->getBuffer();
  }

  cleanup();
  return Result.ReturnCode;
#endif
}
#endif


} // namespace compiler
} // namespace hipsycl
