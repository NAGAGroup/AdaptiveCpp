# Defaults and mirror check for the linux/aarch64 options, run with cmake -P:
#   cmake -P devops/verify/verify-aarch64.cmake

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

set(_aarch64_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/core.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/nvhpc.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/hip.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/ze.cmake
  ${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/omp.cmake)
foreach(_f ${_aarch64_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "aarch64: all cmake files parse clean")

# ---- Defaults check ----

set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "/usr/lib/aarch64-linux-gnu")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/arm/armpl/lib")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

include(${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/core.cmake)

expect_eq(ACPP_TOOLCHAIN_SLEEF_DIR "/usr/lib/aarch64-linux-gnu")
expect_eq(ACPP_APP_SLEEF_DIR "/usr/lib/aarch64-linux-gnu")
expect_eq(ACPP_TOOLCHAIN_AMATH_DIR "/opt/arm/armpl/lib")
expect_eq(ACPP_APP_AMATH_DIR "/opt/arm/armpl/lib")
expect_unset(ACPP_TOOLCHAIN_SVML_DIR)
expect_unset(ACPP_APP_SVML_DIR)
expect_eq(ACPP_VECTOR_MATH_LIB "libmvec")
message(STATUS "aarch64/core.cmake: defaults as declared (no SVML)")

# The architecture files are one-line includes and the configuration is
# fragments across the common tiers, so a text mirror proves nothing;
# verify-common merges the fragments against the goldens.

message(STATUS "aarch64: all checks passed")
