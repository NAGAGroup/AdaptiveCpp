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

# ---- Mirror check: cmake options files ----

foreach(_f cuda nvhpc hip ocl ze omp)
  file(READ "${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/${_f}.cmake" _x86)
  file(READ "${ACPP_REPO_ROOT}/cmake/options/linux/aarch64/${_f}.cmake" _arm)
  string(REPLACE "linux, aarch64" "linux, x86_64" _arm_normalized "${_arm}")
  if(NOT "${_x86}" STREQUAL "${_arm_normalized}")
    message(FATAL_ERROR
      "cmake/options/linux/aarch64/${_f}.cmake differs from x86_64's "
      "beyond the header")
  endif()
  message(STATUS "mirror: ${_f}.cmake identical")
endforeach()

# ---- Mirror check: json files (byte-identical except core and deploy/core) ----

foreach(_f cuda nvhpc hip ocl ze omp)
  file(READ "${ACPP_REPO_ROOT}/config/linux/x86_64/${_f}.json" _x86)
  file(READ "${ACPP_REPO_ROOT}/config/linux/aarch64/${_f}.json" _arm)
  if(NOT "${_x86}" STREQUAL "${_arm}")
    message(FATAL_ERROR "config/linux/aarch64/${_f}.json differs from x86_64's")
  endif()
  message(STATUS "mirror: ${_f}.json identical")
endforeach()

foreach(_f cuda nvhpc hip ocl ze)
  file(READ "${ACPP_REPO_ROOT}/config/linux/x86_64/deploy/${_f}.json" _x86)
  file(READ "${ACPP_REPO_ROOT}/config/linux/aarch64/deploy/${_f}.json" _arm)
  if(NOT "${_x86}" STREQUAL "${_arm}")
    message(FATAL_ERROR "config/linux/aarch64/deploy/${_f}.json differs from x86_64's")
  endif()
  message(STATUS "mirror: deploy/${_f}.json identical")
endforeach()

# ---- Mirror check: core.json (x86_64 minus svml-dir block = aarch64) ----

file(READ "${ACPP_REPO_ROOT}/config/linux/x86_64/core.json" _x86_core)
file(READ "${ACPP_REPO_ROOT}/config/linux/aarch64/core.json" _arm_core)
string(REPLACE
  "  },\n  \"svml-dir\": {\n    \"value\": \"@ACPP_TOOLCHAIN_SVML_DIR@\",\n    \"envvar\": \"ACPP_SVML_DIR\",\n    \"app\": {\n      \"var\": \"ACPP_SVML_DIR\",\n      \"value\": \"@ACPP_APP_SVML_DIR@\",\n      \"runtime-configurable\": true\n    }\n  },\n\n  \"targets\""
  "  },\n\n  \"targets\""
  _x86_core_stripped "${_x86_core}")
if(NOT "${_x86_core_stripped}" STREQUAL "${_arm_core}")
  message(FATAL_ERROR "config/linux/aarch64/core.json differs from x86_64's beyond svml-dir")
endif()
message(STATUS "mirror: core.json identical (minus svml-dir)")

# ---- Mirror check: deploy/core.json (x86_64 minus svml row = aarch64) ----

file(READ "${ACPP_REPO_ROOT}/config/linux/x86_64/deploy/core.json" _x86_deploy)
file(READ "${ACPP_REPO_ROOT}/config/linux/aarch64/deploy/core.json" _arm_deploy)
string(REPLACE
  "  \"external-nonpermissive\": [\n    {\n      \"src\": \"{{ svml-dir }}\",\n      \"dest\": \"{{ acpp-libdir }}\",\n      \"files\": [\n        \"SHARED_LIB:svml\",\n        \"SHARED_LIB:intlc\"\n      ]\n    }\n  ]"
  "  \"external-nonpermissive\": []"
  _x86_deploy_stripped "${_x86_deploy}")
if(NOT "${_x86_deploy_stripped}" STREQUAL "${_arm_deploy}")
  message(FATAL_ERROR "config/linux/aarch64/deploy/core.json differs from x86_64's beyond svml row")
endif()
message(STATUS "mirror: deploy/core.json identical (minus svml row)")

message(STATUS "aarch64: all mirror checks passed")
