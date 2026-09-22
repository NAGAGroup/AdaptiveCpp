# Defaults check for the CUDA options file when no toolkit is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-cuda-placeholder.cmake
#
# Every CUDA discovery export is empty; the options must fall to the
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

# CUDA discovery: nothing found.
set(ACPP_DISCOVERED_CUDA_FOUND OFF)
set(ACPP_DISCOVERED_CUDA_PREFIX "")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "")
set(ACPP_DISCOVERED_CUDA_LIBDIR "")
set(ACPP_DISCOVERED_CUDA_INCDIR "")
set(ACPP_DISCOVERED_CUDA_BINDIR "")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "")
set(ACPP_DISCOVERED_NVCXX "")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)

# Deploy path is independent of discovery.
expect_eq(ACPP_CUDA_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/cuda")

# Provenance: nothing found -> placeholder shape.
expect_eq(ACPP_CUDA_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}")
expect_eq(ACPP_CUDA_LIB_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-libdir }}")
expect_eq(ACPP_CUDA_INCLUDE_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-incdir }}")
expect_eq(ACPP_CUDA_BIN_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-bindir }}")

# Resource: two-sided, not found -> placeholder shape.
expect_eq(ACPP_TOOLCHAIN_CUDA_LIBDEVICE_DIR "{{ toolchain-path }}/{{ cuda-deploy-path }}/nvvm/libdevice")
expect_eq(ACPP_APP_CUDA_LIBDEVICE_DIR "\$ACPP_PATH/{{ cuda-deploy-path }}/nvvm/libdevice")

# nvc++ not found -> bare name.
expect_eq(ACPP_NVCXX "nvc++")

message(STATUS "cuda.cmake (placeholder): parses clean, every default as declared")
