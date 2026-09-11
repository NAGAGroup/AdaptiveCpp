# Defaults check for the platform-split options file, run with cmake -P:
#   cmake -P devops/verify/verify-core.cmake
# (use the cmake the project builds with, e.g. .pixi/envs/dev/bin/cmake)
#
# The discovery stand-ins define every input the options file reads, mixed so
# that all three branches of a declaration run: found (absolute path), empty,
# and NOTFOUND. Provenance entries (llvm-path, libomp-path, libnuma-path) are
# single-sided: one variable each, no ACPP_TOOLCHAIN_ / ACPP_APP_ pair.
# Resource entries (the device compiler, the LLVM tools, clang's resource
# directory, the vector-math directories) are two-sided.
#
# Script mode cannot take -D overrides and CMAKE_SYSTEM_NAME is empty, so
# the non-default strategies and the platform guards are outside this check.

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

# Deploy paths. The linked build installs AdaptiveCpp into the LLVM prefix,
# so the toolchain root and the LLVM root are one tree and LLVM deploys at
# "." - its bin and lib at the root of whatever tree holds them.
expect_eq(ACPP_LLVM_DEPLOY_PATH ".")
expect_eq(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}")
expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs")

# Provenance: single-sided, one variable each. LLVM and libomp were found, so
# they take the discovered branch; libnuma is NOTFOUND, so it falls to the
# placeholder - the exact behaviour deploy needs when a machine lacks it.
expect_eq(ACPP_LLVM_PATH "/usr/lib/llvm-21")
expect_eq(ACPP_LIBOMP_PATH "/usr/lib/llvm-21/lib")
expect_eq(ACPP_LIBNUMA_PATH "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_unset(ACPP_TOOLCHAIN_LLVM_PATH)
expect_unset(ACPP_APP_LLVM_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBOMP_PATH)
expect_unset(ACPP_APP_LIBOMP_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBNUMA_PATH)
expect_unset(ACPP_APP_LIBNUMA_PATH)

# Resources: two-sided. The compiler, tools and clang's resource directory
# were found, so both sides are the discovered absolute path.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "/usr/lib/llvm-21/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "/usr/lib/llvm-21/bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "/usr/lib/llvm-21/bin/llc")
expect_eq(ACPP_APP_LLC "/usr/lib/llvm-21/bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "/usr/lib/llvm-21/bin/opt")
expect_eq(ACPP_APP_OPT "/usr/lib/llvm-21/bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "/usr/lib/llvm-21/bin/ld.lld")
expect_eq(ACPP_APP_LLD "/usr/lib/llvm-21/bin/ld.lld")
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "/usr/lib/llvm-21/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "/usr/lib/llvm-21/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "/usr/lib/llvm-21/lib/clang/21/include")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "/usr/lib/llvm-21/lib/clang/21/include")

# Vector math: SLEEF unset (empty), AMATH found, SVML NOTFOUND - the empty and
# NOTFOUND cases must both fall to the placeholder shape on both sides.
expect_eq(ACPP_TOOLCHAIN_SLEEF_DIR "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_eq(ACPP_APP_SLEEF_DIR "\$ACPP_PATH/{{ acpp-libdir }}")
expect_eq(ACPP_TOOLCHAIN_AMATH_DIR "/opt/amath/lib")
expect_eq(ACPP_APP_AMATH_DIR "/opt/amath/lib")
expect_eq(ACPP_TOOLCHAIN_SVML_DIR "{{ toolchain-path }}/{{ acpp-libdir }}")
expect_eq(ACPP_APP_SVML_DIR "\$ACPP_PATH/{{ acpp-libdir }}")

# Driver-only resources and behaviour.
expect_eq(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
expect_eq(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-libdir }}/libacpp-clang.so")
expect_eq(ACPP_JIT_HOST_LLC_CPU_FLAG "-mcpu=native")
expect_eq(ACPP_JIT_HOST_OPT_CPU_FLAG "--mcpu=native")
expect_eq(ACPP_JIT_HOST_LLC_FLAGS "")
expect_eq(ACPP_JIT_HOST_OPT_FLAGS "")
expect_eq(ACPP_VECTOR_MATH_LIB "libmvec")
expect_eq(ACPP_TARGETS "")

message(STATUS "core.cmake: parses clean, every default as declared")
