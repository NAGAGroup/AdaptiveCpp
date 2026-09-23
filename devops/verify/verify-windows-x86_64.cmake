# Defaults check for the windows/x86_64 options, run with cmake -P:
#   cmake -P devops/verify/verify-windows-x86_64.cmake
#
# This harness runs on Linux; the Windows-only discovery branches are
# parse-checked but not exercised (WIN32 is not defined under -P on Linux).

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

function(expect_unset name)
  if(DEFINED ${name})
    message(FATAL_ERROR "${name} should be unset, is '${${name}}'")
  endif()
endfunction()

# ---- Parse check ----

set(_win_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)
foreach(_f ${_win_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "windows/x86_64: all cmake files parse clean")

# ---- Core defaults ----

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

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake)

expect_eq(ACPP_LLVM_DEPLOY_PATH ".")
expect_eq(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/bin")
expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$LOCALAPPDATA/AdaptiveCpp/app-cfgs")
# LLVM and libomp are ours in toolchain mode (rule 1): always the
# deploy-layout placeholder, `default` strategy notwithstanding.
expect_eq(ACPP_LLVM_PATH "{{ toolchain-path }}/{{ llvm-deploy-path }}")
expect_eq(ACPP_LIBOMP_PATH "{{ toolchain-path }}/{{ libomp-deploy-path }}")
expect_eq(ACPP_TOOLCHAIN_LLD "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/lld-link.exe")
expect_eq(ACPP_APP_LLD "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/lld-link.exe")
expect_eq(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++.exe")
expect_unset(ACPP_PLUGIN_PATH)
expect_eq(ACPP_VECTOR_MATH_LIB "none")
expect_eq(ACPP_SEQUENTIAL_LINK_LINE "-llibomp")
expect_unset(ACPP_TOOLCHAIN_SLEEF_DIR)
expect_unset(ACPP_TOOLCHAIN_AMATH_DIR)
expect_unset(ACPP_TOOLCHAIN_SVML_DIR)
# No LIBNUMA_PATH declared on Windows.
expect_unset(ACPP_LIBNUMA_PATH)
message(STATUS "windows/x86_64/core.cmake: defaults as declared")

# ---- CUDA found ----

set(ACPP_DISCOVERED_CUDA_PREFIX "C:/CUDA/v12.6")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib/x64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "6")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "C:/CUDA/v12.6/nvvm/libdevice")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake)

expect_eq(ACPP_CUDA_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/cuda")
expect_eq(ACPP_CUDA_PATH "C:/CUDA/v12.6")
expect_eq(ACPP_CUDA_LIB_PATH "C:/CUDA/v12.6/lib/x64")
expect_eq(ACPP_CUDA_BIN_PATH "C:/CUDA/v12.6/bin")
expect_eq(ACPP_TOOLCHAIN_CUDA_DLL_DIR "C:/CUDA/v12.6/bin")
expect_eq(ACPP_APP_CUDA_DLL_DIR "C:/CUDA/v12.6/bin")
expect_eq(ACPP_CUDA_LINK_LINE "-L{{ cuda-lib-path }} -lcudart")
message(STATUS "windows/x86_64/cuda.cmake: found defaults as declared")

# ---- OCL found ----

set(ACPP_DISCOVERED_OCL_FOUND ON)
set(ACPP_DISCOVERED_OCL_LOADER "C:/vendor/bin/OpenCL.dll")
set(ACPP_DISCOVERED_OCL_PREFIX "C:/vendor")
set(ACPP_DISCOVERED_OCL_LIBDIR "lib")
set(ACPP_DISCOVERED_OCL_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake)

expect_eq(ACPP_OCL_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_PATH "C:/vendor")
expect_eq(ACPP_OCL_BIN_PATH "C:/vendor/bin")
expect_eq(ACPP_TOOLCHAIN_OCL_DLL_DIR "C:/vendor/bin")
expect_eq(ACPP_APP_OCL_DLL_DIR "C:/vendor/bin")
message(STATUS "windows/x86_64/ocl.cmake: found defaults as declared")

# ---- ZE found ----

set(ACPP_DISCOVERED_ZE_FOUND ON)
set(ACPP_DISCOVERED_ZE_LOADER "C:/vendor/bin/ze_loader.dll")
set(ACPP_DISCOVERED_ZE_PREFIX "C:/vendor")
set(ACPP_DISCOVERED_ZE_LIBDIR "lib")
set(ACPP_DISCOVERED_ZE_BINDIR "bin")
set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "C:/vendor/include")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)

expect_eq(ACPP_ZE_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ze")
expect_eq(ACPP_ZE_PATH "C:/vendor")
expect_eq(ACPP_ZE_BIN_PATH "C:/vendor/bin")
expect_eq(ACPP_TOOLCHAIN_ZE_DLL_DIR "C:/vendor/bin")
expect_eq(ACPP_APP_ZE_DLL_DIR "C:/vendor/bin")
message(STATUS "windows/x86_64/ze.cmake: found defaults as declared")

# ---- OMP (now core) ----

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp")
expect_eq(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
message(STATUS "windows/x86_64 core.cmake: omp values as declared")

# ---- VK found ----

set(ACPP_DISCOVERED_VK_FOUND ON)
set(ACPP_DISCOVERED_VK_LOADER "C:/VulkanSDK/1.4.0/Lib/vulkan-1.lib")
set(ACPP_DISCOVERED_VK_PREFIX "C:/VulkanSDK/1.4.0")
set(ACPP_DISCOVERED_VK_LIBDIR "Lib")
set(ACPP_DISCOVERED_VK_INCLUDE_DIR "C:/VulkanSDK/1.4.0/Include")
set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "C:/VulkanSDK/1.4.0/Lib/SPIRV-Tools.lib")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/vk.cmake)

expect_eq(ACPP_VK_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/vk")
expect_eq(ACPP_VK_PATH "C:/VulkanSDK/1.4.0")
expect_eq(ACPP_VK_LIB_PATH "C:/VulkanSDK/1.4.0/Lib")
message(STATUS "windows/x86_64/vk.cmake: found defaults as declared")

# ---- CLSPV found ----

set(ACPP_DISCOVERED_CLSPV_FOUND ON)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "C:/VulkanSDK/1.4.0/Bin/clspv.exe")
set(ACPP_DISCOVERED_CLSPV_PREFIX "C:/VulkanSDK/1.4.0")
set(ACPP_DISCOVERED_CLSPV_BINDIR "Bin")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/clspv.cmake)

expect_eq(ACPP_CLSPV_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_PATH "C:/VulkanSDK/1.4.0")
expect_eq(ACPP_CLSPV_BIN_PATH "C:/VulkanSDK/1.4.0/Bin")
expect_eq(ACPP_TOOLCHAIN_CLSPV "C:/VulkanSDK/1.4.0/Bin/clspv.exe")
expect_eq(ACPP_APP_CLSPV "C:/VulkanSDK/1.4.0/Bin/clspv.exe")
message(STATUS "windows/x86_64/clspv.cmake: found defaults as declared")

# The architecture files are one-line includes and the configuration is
# fragments across the common tiers, so a text mirror proves nothing;
# verify-common merges the fragments against the goldens.

message(STATUS "windows/x86_64: all checks passed")
