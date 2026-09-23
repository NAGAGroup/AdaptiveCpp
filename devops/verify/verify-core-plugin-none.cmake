# Plugin-mode defaults check when discovery found no plugin to build
# (decision d: ACPP_COMPILER_FEATURE_PROFILE "none", upstream's own default
# outside an LLVM build on macOS and Windows), run with cmake -P:
#   cmake -P devops/verify/verify-core-plugin-none.cmake
#
# Companion to verify-core-plugin.cmake. discovery.cmake exports every
# machine-owned entry empty in this case (never a -NOTFOUND sentinel); this
# harness asserts the options file passes that straight through, empty and
# not an error - a machine resource with nothing discovered has nothing to
# report, which is not the same thing as a configure failure.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Stand-in for cmake/discovery.cmake with ACPP_COMPILER_FEATURE_PROFILE
# "none": every LLVM/clang export is the normalized empty string, exactly
# as discovery.cmake produces when it skips the plugin search.
set(ACPP_DISCOVERED_LLVM_PREFIX "")
set(ACPP_DISCOVERED_LLVM_BINDIR "")
set(ACPP_DISCOVERED_LLVM_LIBDIR "")
set(ACPP_DISCOVERED_CLANG "")
set(ACPP_DISCOVERED_CLANG_INCLUDE "")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")

set(CMAKE_CXX_COMPILER "/usr/bin/g++")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS OFF)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Empty, not an error: no plugin means no plugin-side compiler either.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "")
expect_eq(ACPP_APP_DEVICE_CMPLR "")
expect_eq(ACPP_TOOLCHAIN_LLC "")
expect_eq(ACPP_APP_LLC "")
expect_eq(ACPP_TOOLCHAIN_OPT "")
expect_eq(ACPP_APP_OPT "")
expect_eq(ACPP_TOOLCHAIN_LLD "")
expect_eq(ACPP_APP_LLD "")
# llvm-spirv is ours in both modes and does not depend on the plugin
# search at all, so it stays the deploy-layout placeholder even when no
# plugin was found.
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "{{ toolchain-path }}/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "\$ACPP_PATH/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "")

# cpu-cxx is unaffected: it is the bootstrap compiler, not the plugin.
expect_eq(ACPP_CPU_CXX "/usr/bin/g++")

message(STATUS "core.cmake (plugin mode, no plugin found): empty, not an error, as declared")
