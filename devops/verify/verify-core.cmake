# Defaults check for the platform-split options file, run with cmake -P:
#   cmake -P devops/verify/verify-core.cmake
# (use the cmake the project builds with, e.g. .pixi/envs/dev/bin/cmake)
#
# The discovery stand-ins define every input the options file reads, mixed so
# that all three branches of a vendor declaration run: found (absolute path),
# empty, and NOTFOUND. Provenance entries (llvm-path, libomp-path,
# libnuma-path) are single-sided: one variable each, no ACPP_TOOLCHAIN_ /
# ACPP_APP_ pair. Resource entries (the device compiler, the LLVM tools,
# clang's resource directory, the vector-math directories) are two-sided.
#
# This harness covers TOOLCHAIN mode (LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON):
# the device compiler, the LLVM tools and libomp are ours (rule 1), so they
# are always the deploy-layout placeholder, in every strategy including the
# `default` this harness runs under - ownership, not
# ACPP_DEPLOYMENT_STRATEGY, decides their shape. verify-core-plugin.cmake
# covers plugin mode, where the same entries are the machine's (rule 2).
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

# Deploy paths. Toolchain build: one prefix, one tree, LLVM at its root.
expect_eq(ACPP_LLVM_DEPLOY_PATH ".")
expect_eq(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}")
expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs")

# Provenance: single-sided, one variable each. LLVM and libomp are ours
# (rule 1): always the deploy-layout placeholder, `default` strategy
# notwithstanding - a strategy is a commitment about assets we do not build,
# and these are not that. libnuma stays a vendor plugin (rule 3) governed by
# strategy as before; it is NOTFOUND here, so it falls to the placeholder -
# the exact behaviour deploy needs when a machine lacks it.
expect_eq(ACPP_LLVM_PATH "{{ toolchain-path }}/{{ llvm-deploy-path }}")
expect_eq(ACPP_LIBOMP_PATH "{{ toolchain-path }}/{{ libomp-deploy-path }}")
expect_eq(ACPP_LIBNUMA_PATH "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_unset(ACPP_TOOLCHAIN_LLVM_PATH)
expect_unset(ACPP_APP_LLVM_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBOMP_PATH)
expect_unset(ACPP_APP_LIBOMP_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBNUMA_PATH)
expect_unset(ACPP_APP_LIBNUMA_PATH)

# Resources: two-sided. Ours (rule 1): always the deploy-layout placeholder
# on both sides, in every strategy - discovery's absolute path never reaches
# these in toolchain mode, unlike before the ownership rule.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/llc")
expect_eq(ACPP_APP_LLC "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/opt")
expect_eq(ACPP_APP_OPT "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/ld.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/ld.lld")
# llvm-spirv is ours in both modes (not LLVM's): a fixed placeholder
# under our own library directory, independent of {{ llvm-deploy-path }}.
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "{{ toolchain-path }}/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "\$ACPP_PATH/{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "{{ toolchain-path }}/{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "\$ACPP_PATH/{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")

# Vector math: vendor plugins (rule 3), unaffected by ownership - unchanged
# from before. SLEEF unset (empty), AMATH found, SVML NOTFOUND - the empty
# and NOTFOUND cases must both fall to the placeholder shape on both sides.
expect_eq(ACPP_TOOLCHAIN_SLEEF_DIR "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_eq(ACPP_APP_SLEEF_DIR "\$ACPP_PATH/{{ acpp-libdir }}")
expect_eq(ACPP_TOOLCHAIN_AMATH_DIR "/opt/amath/lib")
expect_eq(ACPP_APP_AMATH_DIR "/opt/amath/lib")
expect_eq(ACPP_TOOLCHAIN_SVML_DIR "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_eq(ACPP_APP_SVML_DIR "\$ACPP_PATH/{{ acpp-libdir }}")

# Driver-only resources and behaviour. cpu-cxx is ours in toolchain mode
# (rule 1): the same placeholder as the device compiler, unconditional. The
# compiler plugin exists as a deployable file only in the plugin build.
expect_eq(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
expect_unset(ACPP_PLUGIN_PATH)
expect_eq(ACPP_JIT_HOST_LLC_CPU_FLAG "-mcpu=native")
expect_eq(ACPP_JIT_HOST_OPT_CPU_FLAG "--mcpu=native")
expect_eq(ACPP_JIT_HOST_LLC_FLAGS "")
expect_eq(ACPP_JIT_HOST_OPT_FLAGS "")
expect_eq(ACPP_VECTOR_MATH_LIB "libmvec")
expect_eq(ACPP_TARGETS "")

message(STATUS "core.cmake: parses clean, every default as declared")
