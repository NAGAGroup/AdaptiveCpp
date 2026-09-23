# Defaults check for the omp values, run with cmake -P:
#   cmake -P devops/verify/verify-omp.cmake
#
# The CPU backend is always built (upstream's WITH_CPU_BACKEND is
# unconditionally true), so the omp flows have no vendor unit: the two
# values live in core.cmake and are checked there. There is no placeholder
# variant; the values are strategy-independent and name no location.

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

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp")
expect_eq(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")

message(STATUS "core.cmake: omp values as declared")
