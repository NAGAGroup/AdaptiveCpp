# Inner process for verify-strategy-matrix.cmake. Never run directly - it
# is spawned once per strategy via `cmake -D ACPP_DEPLOYMENT_STRATEGY=<x>
# [-D ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN=<y>] -P`, for the
# same include_guard(GLOBAL)/FATAL_ERROR reasons
# verify-strategy-cuda-inner.cmake documents.
#
# Includes both cuda.cmake (nonpermissive) and ocl.cmake (permissive) in
# the same process/strategy, to prove the two categories' shipped-ness
# diverge under full-permissive-only without needing two separate runs.
# Prints one RESULT: line per value the outer harness parses back out.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  message(FATAL_ERROR "ACPP_DEPLOYMENT_STRATEGY must be passed via -D")
endif()

# Core stand-ins, same shape as verify-strategy-cuda-inner.cmake/verify-ocl.cmake.
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

# CUDA discovery stand-ins: found (same values verify-strategy-cuda-inner.cmake uses).
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

# OCL discovery stand-ins: found (same values verify-ocl.cmake uses).
set(ACPP_DISCOVERED_OCL_FOUND ON)
set(ACPP_DISCOVERED_OCL_LOADER "/usr/lib/x86_64-linux-gnu/libOpenCL.so.1.0.0")
set(ACPP_DISCOVERED_OCL_PREFIX "/usr")
set(ACPP_DISCOVERED_OCL_LIBDIR "lib/x86_64-linux-gnu")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/ocl.cmake)

message(STATUS "RESULT:ACPP_CUDA_SHIPPED=${ACPP_CUDA_SHIPPED}")
message(STATUS "RESULT:ACPP_OCL_SHIPPED=${ACPP_OCL_SHIPPED}")
message(STATUS "RESULT:ACPP_APP_CUDA_LIBDEVICE_DIR=${ACPP_APP_CUDA_LIBDEVICE_DIR}")
message(STATUS "RESULT:ACPP_APP_OCL_RT_DIR=${ACPP_APP_OCL_RT_DIR}")
