# Inner process for verify-installed-configs.cmake. Never run directly - it
# is spawned via `cmake -D ... -P`, because include_guard(GLOBAL) in the
# options files forbids including core.cmake/cuda.cmake twice in one
# process, and acpp_generate_installed_configs's undefined-@VAR@ check can
# FATAL_ERROR, which -P script mode can only report through the child's own
# exit code and stderr.
#
# Required -D: ACPP_OUT_DIR.
# Optional -D: ACPP_DEPLOYMENT_STRATEGY (default managed, same as core.cmake
# itself), ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN (default OFF),
# ACPP_TEST_UNSET_VAR (a variable name to unset right before generating -
# the negative case: an @VAR@ a template references but that is not
# defined must FATAL_ERROR).

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(NOT DEFINED ACPP_OUT_DIR)
  message(FATAL_ERROR "ACPP_OUT_DIR must be passed via -D")
endif()

# Core stand-ins - identical to verify-core.cmake's toolchain-mode set.
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21")
set(ACPP_DISCOVERED_CLANG_RESOURCE_REL "lib/clang/21")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/amath/lib")
set(ACPP_DISCOVERED_SVML_DIR "")

set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")
set(LLVM_VERSION_MAJOR "21")

# Stand-in for the top-level CMakeLists.txt's own project(VERSION ...)
# setup, which no options file computes - config/common/core.json reads
# these directly. Matches CMakeLists.txt's own current values.
set(ACPP_VERSION_MAJOR "25")
set(ACPP_VERSION_MINOR "10")
set(ACPP_VERSION_PATCH "0")
set(ACPP_VERSION_SUFFIX "")

set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
set(ACPP_LIBOMP_SOURCE_DIR "/usr/lib/llvm-21/lib")

# CUDA stand-ins - identical to verify-cuda.cmake's found case.
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/acpp-installed-configs.cmake)

if(DEFINED ACPP_TEST_UNSET_VAR)
  unset(${ACPP_TEST_UNSET_VAR})
endif()

file(REMOVE_RECURSE "${ACPP_OUT_DIR}")
acpp_generate_installed_configs(
  PLATFORM linux
  ARCH x86_64
  UNITS cuda
  OUT_DIR "${ACPP_OUT_DIR}")

message(STATUS "verify-installed-configs (inner): generated cleanly")
