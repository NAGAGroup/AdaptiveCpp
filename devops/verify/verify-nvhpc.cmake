# Defaults check for the nvhpc options file, run with cmake -P:
#   cmake -P devops/verify/verify-nvhpc.cmake
#
# Stand-ins for the nvhpc discovery exports, the CUDA and core inputs.
# The SDK is found. The placeholder variant (SDK not found) is in
# verify-nvhpc-placeholder.cmake.

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

# CUDA stand-ins (cuda.cmake must load before nvhpc.cmake).
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "/usr/local/cuda-12.9/nvvm/libdevice")

# NVHPC discovery stand-ins: found.
set(ACPP_DISCOVERED_NVHPC_FOUND ON)
set(ACPP_DISCOVERED_NVHPC_NVCXX "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/compilers/bin/nvc++")
set(ACPP_DISCOVERED_NVHPC_PREFIX "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/REDIST")
set(ACPP_DISCOVERED_NVHPC_LIBDIR "compilers/lib")
set(ACPP_DISCOVERED_NVHPC_VERSION_MAJOR "25")
set(ACPP_DISCOVERED_NVHPC_VERSION_MINOR "5")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/nvhpc.cmake)

# Deploy path.
expect_eq(ACPP_NVHPC_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/nvhpc")

# Provenance: SDK found, default strategy -> absolute.
expect_eq(ACPP_NVHPC_PATH "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/REDIST")
expect_eq(ACPP_NVHPC_LIB_PATH "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/REDIST/compilers/lib")

# Driver-only: nvc++ found -> discovered path.
expect_eq(ACPP_NVCXX "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/compilers/bin/nvc++")
expect_eq(ACPP_NVCXX_LINK_LINE "-Mnorpath -Wl,-rpath={{ nvhpc-lib-path }} -Wl,-rpath={{ cuda-lib-path }}")

message(STATUS "nvhpc.cmake: parses clean, every default as declared")
