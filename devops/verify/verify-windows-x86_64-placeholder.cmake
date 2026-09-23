# Defaults check for the windows/x86_64 options when no vendor is found,
# run with cmake -P:
#   cmake -P devops/verify/verify-windows-x86_64-placeholder.cmake
#
# Every vendor discovery export is empty; under `default` strategy the
# vendor unit macros pass discovery's answer straight through, so the
# install root and every subdir fact land empty too. This covers the BIN
# subdirs that double as DLL directories on Windows and are not tested by
# the linux placeholder harnesses.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Core stand-ins.
set(ACPP_DISCOVERED_LLVM_PREFIX "C:/acpp")
set(ACPP_DISCOVERED_LLVM_BINDIR "C:/acpp/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "C:/acpp/bin/clang++.exe")
set(ACPP_DISCOVERED_CLANG_INCLUDE "C:/acpp/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "C:/acpp/bin")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# CUDA: not found.
set(ACPP_DISCOVERED_CUDA_PREFIX "")
set(ACPP_DISCOVERED_CUDA_LIBDIR "")
set(ACPP_DISCOVERED_CUDA_INCDIR "")
set(ACPP_DISCOVERED_CUDA_BINDIR "")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "")

# OCL: not found.
set(ACPP_DISCOVERED_OCL_FOUND OFF)
set(ACPP_DISCOVERED_OCL_LOADER "")
set(ACPP_DISCOVERED_OCL_PREFIX "")
set(ACPP_DISCOVERED_OCL_LIBDIR "")
set(ACPP_DISCOVERED_OCL_BINDIR "")

# ZE: not found.
set(ACPP_DISCOVERED_ZE_FOUND OFF)
set(ACPP_DISCOVERED_ZE_LOADER "")
set(ACPP_DISCOVERED_ZE_PREFIX "")
set(ACPP_DISCOVERED_ZE_LIBDIR "")
set(ACPP_DISCOVERED_ZE_BINDIR "")
set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "")

set(ACPP_DISCOVERED_VK_FOUND OFF)
set(ACPP_DISCOVERED_VK_LOADER "")
set(ACPP_DISCOVERED_VK_PREFIX "")
set(ACPP_DISCOVERED_VK_LIBDIR "")
set(ACPP_DISCOVERED_CLSPV_FOUND OFF)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "")
set(ACPP_DISCOVERED_CLSPV_PREFIX "")
set(ACPP_DISCOVERED_CLSPV_BINDIR "")

# acpp_declare_vendor_subdir's WIN32 branch picks the bindir-rooted default;
# WIN32 is a real platform macro that is false while this harness runs on
# Linux, so the subdir knobs are pre-set here exactly as a Windows configure
# would resolve them by default - the same override path a packager uses.
set(ACPP_CUDA_SUBDIR "bin/hipSYCL/ext/cuda")
set(ACPP_OCL_SUBDIR "bin/hipSYCL/ext/ocl")
set(ACPP_ZE_SUBDIR "bin/hipSYCL/ext/ze")
set(ACPP_VK_SUBDIR "bin/hipSYCL/ext/vk")
set(ACPP_CLSPV_SUBDIR "bin/hipSYCL/ext/clspv")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/vk.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/clspv.cmake)

# ---- CUDA placeholder ----

expect_eq(ACPP_CUDA_SUBDIR "bin/hipSYCL/ext/cuda")
expect_eq(ACPP_CUDA_INSTALL_ROOT "")
expect_eq(ACPP_CUDA_RT_SUBDIR "")
expect_eq(ACPP_CUDA_INCLUDE_SUBDIR "")
expect_eq(ACPP_CUDA_BIN_SUBDIR "")
expect_eq(ACPP_CUDA_LIBDEVICE_SUBDIR "")
expect_eq(ACPP_APP_CUDA_RT_SUBDIR "{{ cuda-install-root }}/{{ cuda-rt-subdir }}")
expect_eq(ACPP_APP_CUDA_BIN_SUBDIR "{{ cuda-install-root }}/{{ cuda-bin-subdir }}")
message(STATUS "windows/x86_64/cuda.cmake (placeholder): defaults as declared")

# ---- OCL placeholder ----

expect_eq(ACPP_OCL_SUBDIR "bin/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_INSTALL_ROOT "")
expect_eq(ACPP_OCL_BIN_SUBDIR "")
expect_eq(ACPP_APP_OCL_BIN_SUBDIR "{{ ocl-install-root }}/{{ ocl-bin-subdir }}")
message(STATUS "windows/x86_64/ocl.cmake (placeholder): defaults as declared")

# ---- ZE placeholder ----

expect_eq(ACPP_ZE_SUBDIR "bin/hipSYCL/ext/ze")
expect_eq(ACPP_ZE_INSTALL_ROOT "")
expect_eq(ACPP_ZE_BIN_SUBDIR "")
expect_eq(ACPP_APP_ZE_BIN_SUBDIR "{{ ze-install-root }}/{{ ze-bin-subdir }}")
message(STATUS "windows/x86_64/ze.cmake (placeholder): defaults as declared")

# ---- VK placeholder ----

expect_eq(ACPP_VK_SUBDIR "bin/hipSYCL/ext/vk")
expect_eq(ACPP_VK_INSTALL_ROOT "")
expect_eq(ACPP_VK_RT_SUBDIR "")
expect_eq(ACPP_APP_VK_RT_SUBDIR "{{ vk-install-root }}/{{ vk-rt-subdir }}")
message(STATUS "windows/x86_64/vk.cmake (placeholder): defaults as declared")

# ---- CLSPV placeholder ----

expect_eq(ACPP_CLSPV_SUBDIR "bin/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_INSTALL_ROOT "")
expect_eq(ACPP_CLSPV_BIN_SUBDIR "")
expect_eq(ACPP_APP_CLSPV_BIN_SUBDIR "{{ clspv-install-root }}/{{ clspv-bin-subdir }}")
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv.exe")
expect_eq(ACPP_APP_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv.exe")
message(STATUS "windows/x86_64/clspv.cmake (placeholder): defaults as declared")

message(STATUS "windows/x86_64 (placeholder): all checks passed")
