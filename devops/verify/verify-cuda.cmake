# Defaults check for the CUDA options file, run with cmake -P:
#   cmake -P devops/verify/verify-cuda.cmake
#
# Stand-ins for the CUDA discovery exports and the core inputs the options
# file inherits. The toolkit is found. The placeholder variant (toolkit not
# found) is in verify-cuda-placeholder.cmake.

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
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# CUDA discovery stand-ins.
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "/usr/local/cuda-12.9/nvvm/libdevice")
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)

# Deploy path.
expect_eq(ACPP_CUDA_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/cuda")

# Provenance: toolkit found, default strategy -> absolute.
expect_eq(ACPP_CUDA_PATH "/usr/local/cuda-12.9")
expect_eq(ACPP_CUDA_LIB_PATH "/usr/local/cuda-12.9/lib64")
expect_eq(ACPP_CUDA_INCLUDE_PATH "/usr/local/cuda-12.9/include")
expect_eq(ACPP_CUDA_BIN_PATH "/usr/local/cuda-12.9/bin")

# Resource: two-sided, found -> absolute.
expect_eq(ACPP_TOOLCHAIN_CUDA_LIBDEVICE_DIR "/usr/local/cuda-12.9/nvvm/libdevice")
expect_eq(ACPP_APP_CUDA_LIBDEVICE_DIR "/usr/local/cuda-12.9/nvvm/libdevice")

# Driver-only: link line and flags.
expect_eq(ACPP_CUDA_LINK_LINE "-Wl,-rpath={{ cuda-lib-path }} -L{{ cuda-lib-path }} -lcudart")
expect_eq(ACPP_CUDA_CXX_FLAGS "-U__FLOAT128__ -U__SIZEOF_FLOAT128__ -isystem {{ toolchain-path }}/include/AdaptiveCpp/hipSYCL/std/hiplike")

message(STATUS "cuda.cmake: parses clean, every default as declared")
