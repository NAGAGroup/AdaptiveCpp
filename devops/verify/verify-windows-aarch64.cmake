# Defaults check for the windows/aarch64 options, run with
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
  ${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/ze.cmake)
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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

set(ACPP_DISCOVERED_CUDA_PREFIX "C:/CUDA/v13.4")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib/arm64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "13")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "4")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

# acpp_declare_vendor_subdir's WIN32 branch picks the bindir-rooted default;
# WIN32 is a real platform macro that is false while this harness runs on
# Linux, so the subdir knob is pre-set here exactly as a Windows configure
# would resolve it by default.
set(ACPP_CUDA_SUBDIR "bin/hipSYCL/ext/cuda")

include(${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/windows/aarch64/cuda.cmake)

expect_eq(ACPP_CUDA_RT_SUBDIR "lib/arm64")
expect_eq(ACPP_CUDA_BIN_SUBDIR "bin")
expect_eq(ACPP_APP_CUDA_BIN_DIR "{{ cuda-install-root }}/{{ cuda-bin-subdir }}")
message(STATUS "windows/aarch64: CUDA arm64 layout needs no file change")

# The architecture files are one-line includes and the configuration is
# fragments across the common tiers, so a text mirror proves nothing;
# verify-common merges the fragments against the goldens.

message(STATUS "windows/aarch64: all checks passed")
