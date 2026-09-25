# Defaults check for the clspv options file, run with cmake -P:
#   cmake -P devops/verify/verify-clspv.cmake

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

# clspv discovery: found.
set(ACPP_DISCOVERED_CLSPV_FOUND ON)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "/opt/vulkan/bin/clspv")
set(ACPP_DISCOVERED_CLSPV_PREFIX "/opt/vulkan")
set(ACPP_DISCOVERED_CLSPV_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/clspv.cmake)

expect_eq(ACPP_CLSPV_SUBDIR "lib/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_INSTALL_ROOT "/opt/vulkan")
expect_eq(ACPP_CLSPV_BIN_SUBDIR "bin")
# Not shipped under managed: a concrete cmake string, the discovered root
# joined with the subdir fact.
expect_eq(ACPP_APP_CLSPV_BIN_DIR "/opt/vulkan/bin")
# The toolchain side composes {{ clspv-install-root }}/{{ clspv-bin-subdir
# }} directly - it needs no shipped branch at configure time, because
# those two entries already carry it when the driver resolves them. The
# app side does need one, and not shipped means the same absolute location
# the driver found, joined with the executable's own name.
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
expect_eq(ACPP_APP_CLSPV "/opt/vulkan/bin/clspv")

message(STATUS "clspv.cmake: parses clean, every default as declared")
