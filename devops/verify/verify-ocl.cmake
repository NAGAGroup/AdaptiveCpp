# Defaults check for the OpenCL options file, run with cmake -P:
#   cmake -P devops/verify/verify-ocl.cmake
#
# Stand-ins for the OpenCL discovery exports and the core inputs the options
# file inherits. The loader is found with a multiarch libdir. The placeholder
# variant (loader not found) is in verify-ocl-placeholder.cmake.

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

# OpenCL discovery stand-ins: found, multiarch layout.
set(ACPP_DISCOVERED_OCL_FOUND ON)
set(ACPP_DISCOVERED_OCL_LOADER "/usr/lib/x86_64-linux-gnu/libOpenCL.so.1.0.0")
set(ACPP_DISCOVERED_OCL_PREFIX "/usr")
set(ACPP_DISCOVERED_OCL_LIBDIR "lib/x86_64-linux-gnu")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/ocl.cmake)

expect_eq(ACPP_OCL_SUBDIR "lib/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_INSTALL_ROOT "/usr")
expect_eq(ACPP_OCL_RT_SUBDIR "lib/x86_64-linux-gnu")
expect_eq(ACPP_APP_OCL_RT_DIR "{{ ocl-install-root }}/{{ ocl-rt-subdir }}")

message(STATUS "ocl.cmake: parses clean, every default as declared")
