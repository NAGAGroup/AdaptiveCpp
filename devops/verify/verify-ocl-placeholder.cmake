# Defaults check for the OpenCL options file when no loader is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-ocl-placeholder.cmake
#
# Every OpenCL discovery export is empty; the options must fall to the
# placeholder shape on every declaration.

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

# OpenCL discovery: nothing found.
set(ACPP_DISCOVERED_OCL_FOUND OFF)
set(ACPP_DISCOVERED_OCL_LOADER "")
set(ACPP_DISCOVERED_OCL_PREFIX "")
set(ACPP_DISCOVERED_OCL_LIBDIR "")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/ocl.cmake)

# Deploy path is independent of discovery.
expect_eq(ACPP_OCL_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/ocl")

# Provenance: not found -> placeholder shape.
expect_eq(ACPP_OCL_PATH "{{ toolchain-path }}/{{ ocl-deploy-path }}")
expect_eq(ACPP_OCL_LIB_PATH "{{ toolchain-path }}/{{ ocl-deploy-path }}/{{ ocl-libdir }}")

message(STATUS "ocl.cmake (placeholder): parses clean, every default as declared")
