# Defaults check for the OpenCL options file when no loader is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-ocl-placeholder.cmake
#
# Every OpenCL discovery export is empty; under `default` strategy the
# vendor unit macro passes discovery's answer straight through, so the
# install root and its subdir fact land empty too.

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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# OpenCL discovery: nothing found.
set(ACPP_DISCOVERED_OCL_FOUND OFF)
set(ACPP_DISCOVERED_OCL_LOADER "")
set(ACPP_DISCOVERED_OCL_PREFIX "")
set(ACPP_DISCOVERED_OCL_LIBDIR "")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/ocl.cmake)

expect_eq(ACPP_OCL_SUBDIR "lib/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_INSTALL_ROOT "")
expect_eq(ACPP_OCL_RT_SUBDIR "")
expect_eq(ACPP_APP_OCL_RT_DIR "{{ ocl-install-root }}/{{ ocl-rt-subdir }}")

message(STATUS "ocl.cmake (placeholder): parses clean, every default as declared")
