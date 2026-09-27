# Defaults check for the platform-split options file, run with cmake -P:
#   cmake -P devops/verify/verify-core.cmake
# (use the cmake the project builds with, e.g. .pixi/envs/dev/bin/cmake)
#
# The discovery stand-ins define every input the options file reads, mixed so
# that all three branches of a vendor declaration run: found (absolute path),
# empty, and NOTFOUND. LLVM has no provenance entry at all any more - what
# toolchain mode builds follows cmake's own install directories directly.
# libnuma, sleef and amath are vendor units (two knobs: an install subdir
# plus discovery's own hints) with their own install-root/app-install-root
# pair - libnuma's is unset, since it is linked, not consumed, and no config
# template reads it. Resource entries (the device compiler, the LLVM tools,
# clang's resource directory) are two-sided.
#
# This harness covers TOOLCHAIN mode (LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON):
# the device compiler, the LLVM tools are ours (rule 1), so they are always
# the deploy-layout placeholder, in every strategy including the `managed`
# this harness runs under - ownership, not ACPP_DEPLOYMENT_STRATEGY, decides
# their shape. libomp is different: it is a vendor unit in every build mode
# now (principle 3), so it is governed by shipped-ness like any other, even
# though its toolchain-mode default source is still ours - see the NOT
# SHIPPED override in common/core.cmake's OMP section, exercised below.
# verify-core-plugin.cmake covers plugin mode, where the device compiler and
# the LLVM tools are the machine's (rule 2) instead.
#
# CMAKE_INSTALL_LIBDIR/CMAKE_INSTALL_BINDIR stand in for what a real
# configure's GNUInstallDirs module would have set before any options file
# is included; every vendor unit's subdir knob defaults off them.
# LLVM_VERSION_MAJOR stands in for what the parent LLVM build already
# computes; clang's resource include directory is composed against it.
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
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21")
set(ACPP_DISCOVERED_CLANG_RESOURCE_REL "lib/clang/21")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/amath/lib")
set(ACPP_DISCOVERED_SVML_DIR "")

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# Stand-in for the parent LLVM build's own version variable, read directly
# now by the owned-resource calls that compose clang's resource directory.
set(LLVM_VERSION_MAJOR "21")

# The toolchain build this harness covers: AdaptiveCpp built as part of the
# LLVM toolchain. The plugin build's mode-dependent defaults are covered by
# verify-core-plugin.cmake. In this mode ACPP_LIBOMP_SOURCE_DIR would
# otherwise default off CMAKE_INSTALL_PREFIX, which this harness never sets
# (script mode never runs project()); stand in directly with the same value
# ACPP_DISCOVERED_LIBOMP_DIR carries, exactly what that default means in a
# real configure - the libomp of the LLVM this build produces.
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
set(ACPP_LIBOMP_SOURCE_DIR "/usr/lib/llvm-21/lib")

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

# Strategy and gate. This harness never sets ACPP_DEPLOYMENT_STRATEGY, so it
# runs under the new default, managed - the ordinary-CMake-project case,
# where nothing is shipped.
expect_eq(ACPP_DEPLOYMENT_STRATEGY "managed")
expect_eq(ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN "OFF")

# LLVM and libomp are ours (rule 1): always the deploy-layout placeholder,
# the strategy notwithstanding - a strategy is a commitment about assets we
# do not build, and these are not that. What we build follows cmake's own
# install directories under {{ acpp-root }} directly - no separate
# deploy-path knob, and no owned-provenance entries for either any more:
# the vendor-unit values below are libomp's actual shape, and LLVM has no
# provenance entry left to have at all.
expect_unset(ACPP_TOOLCHAIN_LLVM_PATH)
expect_unset(ACPP_APP_LLVM_PATH)
expect_unset(ACPP_TOOLCHAIN_LIBOMP_PATH)
expect_unset(ACPP_APP_LIBOMP_PATH)

# libnuma is a vendor unit, permissive: not shipped under managed, so its
# install root is the discovered absolute path however it came out - empty
# here, since discovery found nothing, which is not an error. No
# application-config declaration at all: libnuma is linked, not consumed,
# and no config template reads an install-root value for it.
expect_eq(ACPP_LIBNUMA_SUBDIR "lib/hipSYCL/ext/libnuma")
expect_eq(ACPP_LIBNUMA_SHIPPED "OFF")
expect_eq(ACPP_LIBNUMA_INSTALL_ROOT "")
expect_unset(ACPP_APP_LIBNUMA_INSTALL_ROOT)

# libomp is a vendor unit in every build mode now (principle 3): not
# shipped under managed, same as libnuma. But it is still OURS in toolchain
# mode - built by this same build, not a machine asset - so its install
# root is the deploy-layout placeholder, not ACPP_LIBOMP_SOURCE_DIR's
# absolute value (see common/core.cmake's OMP section for why baking that
# in here would be wrong). ACPP_LIBOMP_DISCOVERED_ROOT still carries the
# absolute value, for the root-wiring commit's install rule to copy from
# when this vendor IS shipped.
expect_eq(ACPP_LIBOMP_SUBDIR "lib/hipSYCL/ext/libomp")
expect_eq(ACPP_LIBOMP_SHIPPED "OFF")
expect_eq(ACPP_LIBOMP_INSTALL_ROOT "{{ acpp-root }}/{{ acpp-libdir }}")
expect_eq(ACPP_LIBOMP_DISCOVERED_ROOT "/usr/lib/llvm-21/lib")
# No application-config declaration on Linux: libomp is linked, not
# consumed, and no config template reads an install-root value for it
# either (Windows keeps one, for AddDllDirectory).
expect_unset(ACPP_APP_LIBOMP_INSTALL_ROOT)

# Resources: two-sided. Ours (rule 1): always the deploy-layout placeholder
# on the toolchain side, in every strategy - discovery's absolute path
# never reaches these in toolchain mode, unlike before the ownership rule.
# CMAKE_INSTALL_BINDIR is "bin" everywhere cmake's own GNU install dirs
# apply (unlike the libdir, which varies), so the segment is written
# literally rather than through a config entry - only Windows names one.
# The application side is now a concrete path from the runtime library's
# own install directory (CMAKE_INSTALL_LIBDIR, "lib" here) to wherever the
# resource lands - "../bin/..." for these, since clang++/llc/opt/lld sit in
# bin, a sibling of lib, not underneath it.
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "{{ acpp-root }}/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "\$ACPP_RT_LIB_DIR/../bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "{{ acpp-root }}/bin/llc")
expect_eq(ACPP_APP_LLC "\$ACPP_RT_LIB_DIR/../bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "{{ acpp-root }}/bin/opt")
expect_eq(ACPP_APP_OPT "\$ACPP_RT_LIB_DIR/../bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "{{ acpp-root }}/bin/ld.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_RT_LIB_DIR/../bin/ld.lld")
# llvm-spirv is ours in both modes (not LLVM's): a fixed placeholder under
# our own library directory, independent of cmake's own LLVM install dirs.
# {{ acpp-libdir }} is gone from the toolchain-side call argument (concrete
# now, "lib"), but {{ acpp-root }} itself is still the driver's own
# resolver's job, so it stays in the toolchain-side text.
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "{{ acpp-root }}/lib/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_APP_LLVMSPIRV "\$ACPP_RT_LIB_DIR/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "{{ acpp-root }}/lib/clang/21")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "\$ACPP_RT_LIB_DIR/clang/21")

# Vector math: vendor units, permissive, unaffected by ownership - not
# shipped under managed, so the discovered absolute path however it came
# out, on both the toolchain and (now, for these no-subdir vendors) the
# application side too - acpp_declare_vendor_app_root's NOT SHIPPED branch
# is the root alone. SLEEF unset (empty), AMATH found, SVML unset.
expect_eq(ACPP_SLEEF_SHIPPED "OFF")
expect_eq(ACPP_SLEEF_INSTALL_ROOT "")
expect_eq(ACPP_APP_SLEEF_INSTALL_ROOT "")
expect_eq(ACPP_AMATH_SHIPPED "OFF")
expect_eq(ACPP_AMATH_INSTALL_ROOT "/opt/amath/lib")
expect_eq(ACPP_APP_AMATH_INSTALL_ROOT "/opt/amath/lib")
expect_eq(ACPP_SVML_SHIPPED "OFF")
expect_eq(ACPP_SVML_INSTALL_ROOT "")
expect_eq(ACPP_APP_SVML_INSTALL_ROOT "")

# Driver-only resources and behaviour. cpu-cxx is ours in toolchain mode
# (rule 1): the same placeholder as the device compiler, unconditional. The
# compiler plugin exists as a deployable file only in the plugin build.
expect_eq(ACPP_CPU_CXX "{{ acpp-root }}/{{ acpp-bindir }}/clang++")
expect_unset(ACPP_PLUGIN_PATH)
expect_eq(ACPP_JIT_HOST_LLC_CPU_FLAG "-mcpu=native")
expect_eq(ACPP_JIT_HOST_OPT_CPU_FLAG "--mcpu=native")
expect_eq(ACPP_JIT_HOST_LLC_FLAGS "")
expect_eq(ACPP_JIT_HOST_OPT_FLAGS "")
expect_eq(ACPP_VECTOR_MATH_LIB "libmvec")
expect_eq(ACPP_TARGETS "")

message(STATUS "core.cmake: parses clean, every default as declared")
