# Defaults check for the windows/x86_64 options when no vendor is found,
# run with cmake -P:
#   cmake -P devops/verify/verify-windows-x86_64-placeholder.cmake
#
# Every vendor discovery export is empty; the options must fall to the
# placeholder shape on every declaration. This covers the DLL_DIR resources
# that exist only on Windows and are not tested by the linux placeholder
# harnesses.

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

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/vk.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/clspv.cmake)

# ---- CUDA placeholder ----

expect_eq(ACPP_CUDA_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/cuda")
expect_eq(ACPP_CUDA_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}")
expect_eq(ACPP_CUDA_LIB_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-libdir }}")
expect_eq(ACPP_CUDA_BIN_PATH "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-bindir }}")
expect_eq(ACPP_TOOLCHAIN_CUDA_DLL_DIR "{{ toolchain-path }}/{{ cuda-deploy-path }}/{{ cuda-bindir }}")
expect_eq(ACPP_APP_CUDA_DLL_DIR "\$ACPP_PATH/{{ cuda-deploy-path }}/{{ cuda-bindir }}")
message(STATUS "windows/x86_64/cuda.cmake (placeholder): defaults as declared")

# ---- OCL placeholder ----

expect_eq(ACPP_OCL_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_PATH "{{ toolchain-path }}/{{ ocl-deploy-path }}")
expect_eq(ACPP_OCL_BIN_PATH "{{ toolchain-path }}/{{ ocl-deploy-path }}/{{ ocl-bindir }}")
expect_eq(ACPP_TOOLCHAIN_OCL_DLL_DIR "{{ toolchain-path }}/{{ ocl-deploy-path }}/{{ ocl-bindir }}")
expect_eq(ACPP_APP_OCL_DLL_DIR "\$ACPP_PATH/{{ ocl-deploy-path }}/{{ ocl-bindir }}")
message(STATUS "windows/x86_64/ocl.cmake (placeholder): defaults as declared")

# ---- ZE placeholder ----

expect_eq(ACPP_ZE_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ze")
expect_eq(ACPP_ZE_PATH "{{ toolchain-path }}/{{ ze-deploy-path }}")
expect_eq(ACPP_ZE_BIN_PATH "{{ toolchain-path }}/{{ ze-deploy-path }}/{{ ze-bindir }}")
expect_eq(ACPP_TOOLCHAIN_ZE_DLL_DIR "{{ toolchain-path }}/{{ ze-deploy-path }}/{{ ze-bindir }}")
expect_eq(ACPP_APP_ZE_DLL_DIR "\$ACPP_PATH/{{ ze-deploy-path }}/{{ ze-bindir }}")
message(STATUS "windows/x86_64/ze.cmake (placeholder): defaults as declared")

# ---- VK placeholder ----

expect_eq(ACPP_VK_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/vk")
expect_eq(ACPP_VK_PATH "{{ toolchain-path }}/{{ vk-deploy-path }}")
expect_eq(ACPP_VK_LIB_PATH "{{ toolchain-path }}/{{ vk-deploy-path }}/{{ vk-libdir }}")
message(STATUS "windows/x86_64/vk.cmake (placeholder): defaults as declared")

# ---- CLSPV placeholder ----

expect_eq(ACPP_CLSPV_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_PATH "{{ toolchain-path }}/{{ clspv-deploy-path }}")
expect_eq(ACPP_CLSPV_BIN_PATH "{{ toolchain-path }}/{{ clspv-deploy-path }}/{{ clspv-bindir }}")
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ toolchain-path }}/{{ clspv-deploy-path }}/{{ clspv-bindir }}/clspv.exe")
expect_eq(ACPP_APP_CLSPV "\$ACPP_PATH/{{ clspv-deploy-path }}/{{ clspv-bindir }}/clspv.exe")
message(STATUS "windows/x86_64/clspv.cmake (placeholder): defaults as declared")

message(STATUS "windows/x86_64 (placeholder): all checks passed")
