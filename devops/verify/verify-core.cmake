# Defaults check for the platform-split options file, run with cmake -P:
#   cmake -P devops/verify/verify-core.cmake
# (use the cmake the project builds with, e.g. .pixi/envs/dev/bin/cmake)
#
# The discovery stand-ins define every input the options file reads, mixed so
# that all three branches of a vendor declaration run: found (absolute path),
# empty, and NOTFOUND. Provenance entries (llvm-path, libomp-path) are
# single-sided: one variable each, no ACPP_TOOLCHAIN_ / ACPP_APP_ pair.
# libnuma, sleef and amath are vendor units (two knobs: an install subdir
# plus discovery's own hints) with their own install-root/app-install-root
# pair. Resource entries (the device compiler, the LLVM tools, clang's
# resource directory) are two-sided.
#
# This harness covers TOOLCHAIN mode (LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON):
# the device compiler, the LLVM tools and libomp are ours (rule 1), so they
# are always the deploy-layout placeholder, in every strategy including the
# `default` this harness runs under - ownership, not
# ACPP_DEPLOYMENT_STRATEGY, decides their shape. verify-core-plugin.cmake
# covers plugin mode, where the same entries are the machine's (rule 2).
#
# CMAKE_INSTALL_LIBDIR/CMAKE_INSTALL_BINDIR stand in for what a real
# configure's GNUInstallDirs module would have set before any options file
# is included; every vendor unit's subdir knob defaults off them.
#
# Script mode cannot take -D overrides and CMAKE_SYSTEM_NAME is empty, so
# the platform guards are outside this check.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Stand-in for cmake/discovery.cmake, which runs before the options files
# and exports every input they declare. Not-found is the normalized empty
# string - discovery never exports a -NOTFOUND sentinel.
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

# The toolchain build this harness covers: AdaptiveCpp built as part of the
# LLVM toolchain. The plugin build's mode-dependent defaults are covered by
# verify-core-plugin.cmake.
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

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

# Strategy and gate.
expect_eq(ACPP_DEPLOYMENT_STRATEGY "default")
expect_eq(ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN "OFF")
expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs")

# Provenance: single-sided, one variable each. LLVM and libomp are ours
# (rule 1): always the deploy-layout placeholder, `default` strategy
# notwithstanding - a strategy is a commitment about assets we do not build,
# and these are not that. What we build follows cmake's own install
# directories under {{ acpp-root }} directly - no separate deploy-path knob.
expect_eq(ACPP_LLVM_PATH "{{ acpp-root }}/{{ acpp-libdir }}")
expect_eq(ACPP_LIBOMP_PATH "{{ acpp-root }}/{{ acpp-libdir }}")
expect_unset(ACPP_TOOLCHAIN_LLVM_PATH)
expect_unset(ACPP_APP_LLVM_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBOMP_PATH)
expect_unset(ACPP_APP_LIBOMP_PATH)

# libnuma is a vendor unit (rule 3/4): two knobs (an install subdir plus
# discovery's own hint), the discovered absolute path under `default`
# however it came out - empty here, since discovery found nothing, which is
# not an error. LIBOMP_SUBDIR/INSTALL_ROOT are never declared in toolchain
# mode: libomp is ours here (see above), not a vendor plugin.
expect_eq(ACPP_LIBNUMA_SUBDIR "lib/hipSYCL/ext/libnuma")
expect_eq(ACPP_LIBNUMA_INSTALL_ROOT "")
expect_eq(ACPP_APP_LIBNUMA_INSTALL_ROOT "{{ libnuma-install-root }}")
expect_unset(ACPP_LIBOMP_SUBDIR)
expect_unset(ACPP_LIBOMP_INSTALL_ROOT)

# Resources: two-sided. Ours (rule 1): always the deploy-layout placeholder
# on both sides, in every strategy - discovery's absolute path never reaches
# these in toolchain mode, unlike before the ownership rule. CMAKE_INSTALL_
# BINDIR is "bin" everywhere cmake's own GNU install dirs apply (unlike the
# libdir, which varies), so the segment is written literally rather than
# through a config entry - only Windows names one.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "{{ acpp-root }}/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "\$ACPP_RUNTIME_ROOT/bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "{{ acpp-root }}/bin/llc")
expect_eq(ACPP_APP_LLC "\$ACPP_RUNTIME_ROOT/bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "{{ acpp-root }}/bin/opt")
expect_eq(ACPP_APP_OPT "\$ACPP_RUNTIME_ROOT/bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "{{ acpp-root }}/bin/ld.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_RUNTIME_ROOT/bin/ld.lld")
# llvm-spirv is ours in both modes (not LLVM's): a fixed placeholder
# under our own library directory, independent of cmake's own LLVM install
# dirs.
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "{{ acpp-root }}/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "\$ACPP_RUNTIME_ROOT/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "{{ acpp-root }}/{{ acpp-libdir }}/clang/{{ llvm-version-major }}/include")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "\$ACPP_RUNTIME_ROOT/{{ acpp-libdir }}/clang/{{ llvm-version-major }}/include")

# Vector math: vendor units (rule 3/4), unaffected by ownership - the
# discovered absolute path under `default` however it came out. SLEEF
# unset (empty), AMATH found, SVML unset - all three fall straight through,
# empty or not, because `default` no longer special-cases not-found the way
# the old two-sided resource macros did.
expect_eq(ACPP_SLEEF_INSTALL_ROOT "")
expect_eq(ACPP_APP_SLEEF_INSTALL_ROOT "{{ sleef-install-root }}")
expect_eq(ACPP_AMATH_INSTALL_ROOT "/opt/amath/lib")
expect_eq(ACPP_APP_AMATH_INSTALL_ROOT "{{ amath-install-root }}")
expect_eq(ACPP_SVML_INSTALL_ROOT "")
expect_eq(ACPP_APP_SVML_INSTALL_ROOT "{{ svml-install-root }}")

# Driver-only resources and behaviour. cpu-cxx is ours in toolchain mode
# (rule 1): the same placeholder as the device compiler, unconditional. The
# compiler plugin exists as a deployable file only in the plugin build.
expect_eq(ACPP_CPU_CXX "{{ acpp-root }}/bin/clang++")
expect_unset(ACPP_PLUGIN_PATH)
expect_eq(ACPP_JIT_HOST_LLC_CPU_FLAG "-mcpu=native")
expect_eq(ACPP_JIT_HOST_OPT_CPU_FLAG "--mcpu=native")
expect_eq(ACPP_JIT_HOST_LLC_FLAGS "")
expect_eq(ACPP_JIT_HOST_OPT_FLAGS "")
expect_eq(ACPP_VECTOR_MATH_LIB "libmvec")
expect_eq(ACPP_TARGETS "")

message(STATUS "core.cmake: parses clean, every default as declared")
