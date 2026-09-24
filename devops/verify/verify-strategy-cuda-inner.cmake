# Inner process for verify-strategy-cuda.cmake. Never run directly - it is
# spawned once per strategy via `cmake -D ACPP_DEPLOYMENT_STRATEGY=<x> -P`,
# because include_guard(GLOBAL) in the options files forbids including
# cuda.cmake twice in one process, and three strategies need three runs.
# ACPP_CUDA_SUBDIR may also be passed via -D, for the conda-shaped case
# (empty string - installs straight at the root).
#
# Prints one RESULT: line per value the outer harness parses back out.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  message(FATAL_ERROR "ACPP_DEPLOYMENT_STRATEGY must be passed via -D")
endif()

# Core stand-ins, same shape as verify-cuda.cmake.
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# CUDA discovery stand-ins: found.
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

message(STATUS "RESULT:ACPP_CUDA_SUBDIR=${ACPP_CUDA_SUBDIR}")
message(STATUS "RESULT:ACPP_CUDA_INSTALL_ROOT=${ACPP_CUDA_INSTALL_ROOT}")
message(STATUS "RESULT:ACPP_APP_CUDA_LIBDEVICE_DIR=${ACPP_APP_CUDA_LIBDEVICE_DIR}")
