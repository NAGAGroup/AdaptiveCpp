# Defaults check for the macos/arm64 options, run with cmake -P:
#   cmake -P devops/verify/verify-macos-arm64.cmake

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

set(_macos_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake
  ${ACPP_REPO_ROOT}/cmake/options/macos/arm64/omp.cmake)
foreach(_f ${_macos_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "macos/arm64: all cmake files parse clean")

# ---- Core defaults ----

set(ACPP_DISCOVERED_LLVM_PREFIX "/opt/acpp")
set(ACPP_DISCOVERED_LLVM_BINDIR "/opt/acpp/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/opt/acpp/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/opt/acpp/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "/opt/acpp/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake)

expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$HOME/Library/Application Support/AdaptiveCpp/app-cfgs")
expect_eq(ACPP_TOOLCHAIN_LLD "/opt/acpp/bin/ld64.lld")
expect_eq(ACPP_APP_LLD "/opt/acpp/bin/ld64.lld")
expect_eq(ACPP_VECTOR_MATH_LIB "none")
expect_eq(ACPP_SEQUENTIAL_LINK_LINE "-L{{ libomp-path }} -lomp")
expect_eq(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
expect_unset(ACPP_PLUGIN_PATH)
expect_unset(ACPP_LIBNUMA_PATH)
expect_unset(ACPP_TOOLCHAIN_SLEEF_DIR)
expect_unset(ACPP_TOOLCHAIN_AMATH_DIR)
expect_unset(ACPP_TOOLCHAIN_SVML_DIR)
message(STATUS "macos/arm64/core.cmake: defaults as declared")

# ---- OMP ----

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/omp.cmake)

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp -L{{ libomp-path }} -lomp")
expect_eq(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
message(STATUS "macos/arm64/omp.cmake: defaults as declared")

# ---- VK found ----

set(ACPP_DISCOVERED_VK_FOUND ON)
set(ACPP_DISCOVERED_VK_LOADER "/opt/vulkansdk/macOS/lib/libvulkan.1.4.0.dylib")
set(ACPP_DISCOVERED_VK_PREFIX "/opt/vulkansdk/macOS")
set(ACPP_DISCOVERED_VK_LIBDIR "lib")
set(ACPP_DISCOVERED_VK_INCLUDE_DIR "/opt/vulkansdk/macOS/include")
set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "/opt/vulkansdk/macOS/lib/libSPIRV-Tools.a")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/vk.cmake)

expect_eq(ACPP_VK_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/vk")
expect_eq(ACPP_VK_PATH "/opt/vulkansdk/macOS")
expect_eq(ACPP_VK_LIB_PATH "/opt/vulkansdk/macOS/lib")
message(STATUS "macos/arm64/vk.cmake: found defaults as declared")

# ---- CLSPV found ----

set(ACPP_DISCOVERED_CLSPV_FOUND ON)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "/opt/vulkansdk/macOS/bin/clspv")
set(ACPP_DISCOVERED_CLSPV_PREFIX "/opt/vulkansdk/macOS")
set(ACPP_DISCOVERED_CLSPV_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/clspv.cmake)

expect_eq(ACPP_CLSPV_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/clspv")
expect_eq(ACPP_TOOLCHAIN_CLSPV "/opt/vulkansdk/macOS/bin/clspv")
expect_eq(ACPP_APP_CLSPV "/opt/vulkansdk/macOS/bin/clspv")
message(STATUS "macos/arm64/clspv.cmake: found defaults as declared")

message(STATUS "macos/arm64: all checks passed")
