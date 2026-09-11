# Plugin-mode defaults check for the platform-split options file, run with
# cmake -P:
#   cmake -P devops/verify/verify-core-plugin.cmake
#
# Companion to verify-core.cmake, which covers the linked build. Script mode
# cannot take -D overrides and include_guard(GLOBAL) in the options file
# prevents including it twice in one process, so the two modes are separate
# files. This one asserts only the values that depend on the mode; every
# other default is shared and covered by the linked harness.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Stand-in for cmake/discovery.cmake, which does not exist yet.
set(LLVM_INSTALL_PREFIX "/usr/lib/llvm-21")
set(CLANG_EXECUTABLE_PATH "/usr/lib/llvm-21/bin/clang++")
set(CLANG_INCLUDE_PATH "/usr/lib/llvm-21/lib/clang/21/include")
set(LLVM_TOOLS_BINARY_DIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "NUMA_LIBRARY-NOTFOUND")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/amath/lib")
set(ACPP_DISCOVERED_SVML_DIR "LIBSVML-NOTFOUND")

# The plugin build: AdaptiveCpp added to an existing LLVM, not linked into
# one we build.
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS OFF)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# The plugin build's toolchain tree is ours alone; a bundled LLVM unit
# travels under our library directory.
expect_eq(ACPP_LLVM_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext")

# The compiler plugin exists as a deployable file only in the plugin build.
expect_eq(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-libdir }}/libacpp-clang.so")

message(STATUS "core.cmake (plugin mode): parses clean, mode-dependent defaults as declared")
