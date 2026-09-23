# Plugin-mode defaults check for the platform-split options file, run with
# cmake -P:
#   cmake -P devops/verify/verify-core-plugin.cmake
#
# Companion to verify-core.cmake, which covers the toolchain build. Script
# mode cannot take -D overrides and include_guard(GLOBAL) in the options
# file prevents including it twice in one process, so the two modes are
# separate files. This one asserts the ownership-governed entries: in
# plugin mode the device compiler, the LLVM tools and cpu-cxx belong to the
# machine (rule 2) - always the discovered absolute path, in every
# strategy - and libomp is a vendor unit (rule 4), two knobs (an install
# subdir plus discovery's own hint), governed by ACPP_DEPLOYMENT_STRATEGY
# like any other. Every other default is shared and covered by the
# toolchain harness.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Stand-in for cmake/discovery.cmake, which runs before the options files
# and exports every input they declare.
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/amath/lib")
set(ACPP_DISCOVERED_SVML_DIR "")

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# Stand-in for the bootstrap compiler AdaptiveCpp itself was built with -
# upstream's HIPSYCL_CPU_CXX, CMAKE_CXX_COMPILER exactly. Script mode never
# runs project(), so nothing sets this without the stand-in.
set(CMAKE_CXX_COMPILER "/usr/bin/g++")

# The plugin build: AdaptiveCpp added to an existing LLVM, not linked into
# one we build.
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS OFF)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)

function(expect_unset name)
  if(DEFINED ${name})
    message(FATAL_ERROR "${name} should be unset, is '${${name}}'")
  endif()
endfunction()

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# LLVM is the machine's in plugin mode (rule 2): never bundled, so there is
# no LLVM provenance at all - always empty.
expect_eq(ACPP_LLVM_PATH "")
expect_unset(ACPP_TOOLCHAIN_LLVM_PATH)
expect_unset(ACPP_APP_LLVM_PATH)

# libomp is a vendor unit here (rule 4): two knobs (an install subdir plus
# discovery's own hint), governed by ACPP_DEPLOYMENT_STRATEGY like any
# other; found and `default` strategy, so the install root takes the
# discovered absolute path. There is no ACPP_LIBOMP_PATH at all in this
# mode - that name belongs to the owned (toolchain-mode) shape only.
expect_eq(ACPP_LIBOMP_SUBDIR "lib/hipSYCL/ext/libomp")
expect_eq(ACPP_LIBOMP_INSTALL_ROOT "/usr/lib/llvm-21/lib")
expect_eq(ACPP_APP_LIBOMP_INSTALL_ROOT "{{ libomp-install-root }}")
expect_unset(ACPP_LIBOMP_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBOMP_PATH)
expect_unset(ACPP_APP_LIBOMP_PATH)

# The device compiler, the LLVM tools and clang's resource directory belong
# to the machine (rule 2): both sides are the discovered absolute path,
# `default` strategy notwithstanding - there is no placeholder shape for
# these in plugin mode at all.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "/usr/lib/llvm-21/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "/usr/lib/llvm-21/bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "/usr/lib/llvm-21/bin/llc")
expect_eq(ACPP_APP_LLC "/usr/lib/llvm-21/bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "/usr/lib/llvm-21/bin/opt")
expect_eq(ACPP_APP_OPT "/usr/lib/llvm-21/bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "/usr/lib/llvm-21/bin/ld.lld")
expect_eq(ACPP_APP_LLD "/usr/lib/llvm-21/bin/ld.lld")
# llvm-spirv is ours in both modes (not LLVM's): the machine's LLVM never
# supplies it, plugin or not, so it stays the deploy-layout placeholder
# here too, unaffected by what discovery found for the plugin.
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "{{ acpp-root }}/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "\$ACPP_RUNTIME_ROOT/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "/usr/lib/llvm-21/lib/clang/21/include")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "/usr/lib/llvm-21/lib/clang/21/include")

# cpu-cxx is the machine's build compiler (rule 2), upstream's exact
# formula: CMAKE_CXX_COMPILER, absolute, unconditional.
expect_eq(ACPP_CPU_CXX "/usr/bin/g++")

# The compiler plugin exists as a deployable file only in the plugin build,
# and it is ours (rule 1): always the placeholder, no override.
expect_eq(ACPP_PLUGIN_PATH "{{ acpp-root }}/{{ acpp-libdir }}/libacpp-clang.so")

message(STATUS "core.cmake (plugin mode): parses clean, mode-dependent defaults as declared")
