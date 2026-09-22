# Defaults check for the clspv options file when clspv is not found,
# run with cmake -P:
#   cmake -P devops/verify/verify-clspv-placeholder.cmake

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

# clspv discovery: nothing found.
set(ACPP_DISCOVERED_CLSPV_FOUND OFF)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "")
set(ACPP_DISCOVERED_CLSPV_PREFIX "")
set(ACPP_DISCOVERED_CLSPV_BINDIR "")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/clspv.cmake)

expect_eq(ACPP_CLSPV_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_PATH "{{ toolchain-path }}/{{ clspv-deploy-path }}")
expect_eq(ACPP_CLSPV_BIN_PATH "{{ toolchain-path }}/{{ clspv-deploy-path }}/{{ clspv-bindir }}")
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ toolchain-path }}/{{ clspv-deploy-path }}/{{ clspv-bindir }}/clspv")
expect_eq(ACPP_APP_CLSPV "\$ACPP_PATH/{{ clspv-deploy-path }}/{{ clspv-bindir }}/clspv")

message(STATUS "clspv.cmake (placeholder): parses clean, every default as declared")
