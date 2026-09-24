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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# CUDA stand-ins (cuda.cmake must load before nvhpc.cmake). LIBDEVICE_DIR is
# relative to the prefix, like the other three - discovery's common-ancestor
# derivation.
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

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

# The install subdir knob and the root it derives. ACPP_DISCOVERED_NVHPC_
# PREFIX is already the SDK's REDIST root, not the SDK root itself.
expect_eq(ACPP_NVHPC_SUBDIR "lib/hipSYCL/ext/nvhpc")
expect_eq(ACPP_NVHPC_INSTALL_ROOT "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/REDIST")
expect_eq(ACPP_NVHPC_RT_SUBDIR "compilers/lib")
expect_eq(ACPP_APP_NVHPC_RT_DIR "{{ nvhpc-install-root }}/{{ nvhpc-rt-subdir }}")

# Driver-only: nvc++ found -> discovered path.
expect_eq(ACPP_NVCXX "/opt/nvidia/hpc_sdk/Linux_x86_64/25.5/compilers/bin/nvc++")
expect_eq(ACPP_NVCXX_LINK_LINE "-Mnorpath -Wl,-rpath={{ nvhpc-install-root }}/{{ nvhpc-rt-subdir }} -Wl,-rpath={{ cuda-install-root }}/{{ cuda-rt-subdir }}")

message(STATUS "nvhpc.cmake: parses clean, every default as declared")
