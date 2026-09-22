# Defaults and mirror check for the windows/aarch64 options, run with
# cmake -P:
#   cmake -P devops/verify/verify-windows-aarch64.cmake
#
# This harness runs on Linux; the Windows-only discovery branches are
# parse-checked but not exercised.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# ---- Parse check ----

set(_win_arm_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/core.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/ze.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/omp.cmake)
foreach(_f ${_win_arm_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "windows/aarch64: all cmake files parse clean")

# ---- Defaults check: CUDA with arm64 layout ----

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

set(ACPP_DISCOVERED_CUDA_PREFIX "C:/CUDA/v13.4")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib/arm64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "13")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "4")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "C:/CUDA/v13.4/nvvm/libdevice")

include(${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/cuda.cmake)

expect_eq(ACPP_CUDA_LIB_PATH "C:/CUDA/v13.4/lib/arm64")
expect_eq(ACPP_CUDA_BIN_PATH "C:/CUDA/v13.4/bin")
expect_eq(ACPP_TOOLCHAIN_CUDA_DLL_DIR "C:/CUDA/v13.4/bin")
expect_eq(ACPP_APP_CUDA_DLL_DIR "C:/CUDA/v13.4/bin")
message(STATUS "windows/aarch64: CUDA arm64 layout needs no file change")

# ---- Mirror check: cmake options files ----

foreach(_f core cuda ocl ze omp vk clspv)
  file(READ "${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/${_f}.cmake" _x64)
  file(READ "${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/${_f}.cmake" _arm)
  string(REPLACE "windows, aarch64" "windows, x86_64" _arm_normalized "${_arm}")
  if(NOT "${_x64}" STREQUAL "${_arm_normalized}")
    message(FATAL_ERROR
      "cmake/options/windows/aarch64/${_f}.cmake differs from x86_64's "
      "beyond the header")
  endif()
  message(STATUS "mirror: ${_f}.cmake identical")
endforeach()

# ---- Mirror check: json files (byte-identical) ----

foreach(_f core cuda ocl ze omp vk clspv)
  file(READ "${ACPP_REPO_ROOT}/config/windows/x86_64/${_f}.json" _x64)
  file(READ "${ACPP_REPO_ROOT}/config/windows/aarch64/${_f}.json" _arm)
  if(NOT "${_x64}" STREQUAL "${_arm}")
    message(FATAL_ERROR "config/windows/aarch64/${_f}.json differs from x86_64's")
  endif()
  message(STATUS "mirror: ${_f}.json identical")
endforeach()

foreach(_f core cuda ocl ze vk clspv)
  file(READ "${ACPP_REPO_ROOT}/config/windows/x86_64/deploy/${_f}.json" _x64)
  file(READ "${ACPP_REPO_ROOT}/config/windows/aarch64/deploy/${_f}.json" _arm)
  if(NOT "${_x64}" STREQUAL "${_arm}")
    message(FATAL_ERROR "config/windows/aarch64/deploy/${_f}.json differs from x86_64's")
  endif()
  message(STATUS "mirror: deploy/${_f}.json identical")
endforeach()

message(STATUS "windows/aarch64: all mirror checks passed")
