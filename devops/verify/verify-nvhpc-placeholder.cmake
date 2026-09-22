# Defaults check for the nvhpc options file when the SDK is not found, run
# with cmake -P:
#   cmake -P devops/verify/verify-nvhpc-placeholder.cmake
#
# Every nvhpc discovery export is empty; the options must fall to the
# placeholder shape on every declaration.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Core stand-ins.
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# CUDA stand-ins (empty).
set(ACPP_DISCOVERED_CUDA_FOUND OFF)
set(ACPP_DISCOVERED_CUDA_PREFIX "")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "")
set(ACPP_DISCOVERED_CUDA_LIBDIR "")
set(ACPP_DISCOVERED_CUDA_INCDIR "")
set(ACPP_DISCOVERED_CUDA_BINDIR "")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "")

# NVHPC discovery: nothing found.
set(ACPP_DISCOVERED_NVHPC_FOUND OFF)
set(ACPP_DISCOVERED_NVHPC_NVCXX "")
set(ACPP_DISCOVERED_NVHPC_PREFIX "")
set(ACPP_DISCOVERED_NVHPC_LIBDIR "")
set(ACPP_DISCOVERED_NVHPC_VERSION_MAJOR "")
set(ACPP_DISCOVERED_NVHPC_VERSION_MINOR "")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/nvhpc.cmake)

# Deploy path is independent of discovery.
expect_eq(ACPP_NVHPC_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/nvhpc")

# Provenance: not found -> placeholder shape.
expect_eq(ACPP_NVHPC_PATH "{{ toolchain-path }}/{{ nvhpc-deploy-path }}")
expect_eq(ACPP_NVHPC_LIB_PATH "{{ toolchain-path }}/{{ nvhpc-deploy-path }}/{{ nvhpc-libdir }}")

# nvc++ not found -> bare name.
expect_eq(ACPP_NVCXX "nvc++")

message(STATUS "nvhpc.cmake (placeholder): parses clean, every default as declared")
