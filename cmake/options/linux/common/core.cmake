# Core options - linux, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------

# Where the LLVM unit lands, in toolchain mode only - LLVM is ours there
# (rule 1: one prefix, one tree, LLVM's bin and lib sit at its root: ".").
# In plugin mode LLVM is the machine's (rule 2): it is never bundled, so
# this key is unused; it stays defined and empty rather than absent, for
# the same reason every arch file stays present even when it changes
# nothing.
acpp_require_relative(ACPP_LLVM_DEPLOY_PATH)
if(NOT DEFINED ACPP_LLVM_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LLVM_DEPLOY_PATH ".")
  else()
    set(ACPP_LLVM_DEPLOY_PATH "")
  endif()
endif()

# Where libomp lands. In toolchain mode it is ours, travelling with the LLVM
# we build. In plugin mode it is a vendor plugin (rule 4: it provides
# compute) with no LLVM tree of its own to travel with, so it deploys
# beside our own libraries like any other vendor plugin, governed by
# ACPP_DEPLOYMENT_STRATEGY; a packager using libgomp instead points this at
# wherever they want it.
acpp_require_relative(ACPP_LIBOMP_DEPLOY_PATH)
if(NOT DEFINED ACPP_LIBOMP_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}")
  else()
    set(ACPP_LIBOMP_DEPLOY_PATH "{{ acpp-libdir }}")
  endif()
endif()

# Where the deploy step writes application configurations under `default`,
# where nothing is copied and the application's tree holds none of our
# libraries. The default covers a user compiling for themselves; a
# distribution maintainer building in `default` mode points it at the system
# configuration directory.
#
# Deliberately NOT subject to acpp_require_relative: this is the one path
# meant to be absolute and to point outside the tree.
if(NOT DEFINED ACPP_DEFAULT_STRATEGY_APP_CFG_DIR)
  set(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------
#
# LLVM and libomp split by ownership (see "Ownership" in the common file):
# toolchain mode builds them, so they are ours, always at the deploy layout,
# in every strategy including `default`. Plugin mode's libomp is a vendor
# plugin instead, governed by strategy like any other; plugin mode has no
# LLVM provenance at all, because nothing of the machine's LLVM is ever
# copied.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_provenance(ACPP_LLVM_PATH "{{ llvm-deploy-path }}")
  acpp_declare_owned_provenance(ACPP_LIBOMP_PATH "{{ libomp-deploy-path }}")
else()
  set(ACPP_LLVM_PATH "")
  acpp_declare_provenance(ACPP_LIBOMP_PATH ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}" "{{ libomp-deploy-path }}")
endif()

# libnuma is an ordinary shared library with no internal structure to
# preserve, so it needs no deploy path of its own: it goes beside our
# libraries, where the loader finds it. A vendor plugin in every mode -
# libnuma is never something we build.
acpp_declare_provenance(ACPP_LIBNUMA_PATH ACPP_DISCOVERED_LIBNUMA_DIR "${ACPP_DISCOVERED_LIBNUMA_DIR}" "{{ acpp-libdir }}")

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# The device compiler is used by the multipass flows AND by the generic JIT,
# which is exactly why it has two sides: the driver invokes it from the
# toolchain while compiling, the JIT invokes it from the deployment while an
# application runs, and those need not be the same binary.
#
# Ownership, not deployment strategy, decides which shape these five take
# (see "Ownership" in the common file). Toolchain mode builds this LLVM, so
# it is ours: always the deploy-layout placeholder, in every strategy.
# Plugin mode's LLVM is the machine's (rule 2): always the discovered
# absolute path, in every strategy, empty and not an error when discovery
# found no plugin to build (decision d).

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_resource(DEVICE_CMPLR "{{ llvm-deploy-path }}/bin/clang++")
  acpp_declare_owned_resource(LLC "{{ llvm-deploy-path }}/bin/llc")
  acpp_declare_owned_resource(OPT "{{ llvm-deploy-path }}/bin/opt")
  acpp_declare_owned_resource(LLD "{{ llvm-deploy-path }}/bin/ld.lld")
  # clang's resource include directory. The JIT's HIP compilation needs it,
  # so it has two sides like the compiler itself.
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")
else()
  acpp_declare_machine_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}")
  acpp_declare_machine_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc")
  acpp_declare_machine_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt")
  acpp_declare_machine_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/ld.lld")
  acpp_declare_machine_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}")
endif()

# llvm-spirv is not LLVM's: AdaptiveCpp builds its own fork of the
# SPIRV-LLVM-Translator and installs it under its own library directory
# (doc/install-ocl.md), independent of {{ llvm-deploy-path }}. Ours in
# BOTH modes (rule 1) - the machine's LLVM never supplies it, plugin or
# not - always the deploy-layout placeholder, in every strategy.
acpp_declare_owned_resource(LLVMSPIRV "{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")

# The vector math libraries, each directory-valued because the library's short
# name is written into the JIT's link invocation. They deploy beside our own
# libraries, having no internal structure to preserve. libmvec needs no entry:
# it is part of glibc, so the only correct copy is the one the loader resolves
# in the running process. SVML is x86-only and lives in the arch file. Vendor
# plugins in every mode - none of these are ours to build.
acpp_declare_resource(SLEEF_DIR ACPP_DISCOVERED_SLEEF_DIR "${ACPP_DISCOVERED_SLEEF_DIR}" "{{ acpp-libdir }}")
acpp_declare_resource(AMATH_DIR ACPP_DISCOVERED_AMATH_DIR "${ACPP_DISCOVERED_AMATH_DIR}" "{{ acpp-libdir }}")

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# The host C++ compiler the driver invokes for CPU code. Ownership, not
# strategy, decides its shape: in toolchain mode it is our own clang++,
# always the deploy-layout placeholder in every strategy (rule 1). In
# plugin mode it is upstream's HIPSYCL_CPU_CXX exactly: the machine's own
# build compiler (CMAKE_CXX_COMPILER), the one AdaptiveCpp itself was built
# with, absolute, in every strategy, overridable only by reconfiguring with
# a different CMAKE_CXX_COMPILER - not by a strategy choice.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
else()
  set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
endif()

# The compiler plugin, in plugin builds only. We always build our own
# plugin file, so it is ours (rule 1): always the deploy-layout placeholder,
# in every strategy including `default`, with no override - a strategy
# choice is about vendor assets we do not build, and this is not one. When
# AdaptiveCpp is linked into the LLVM tools there is no plugin file and the
# driver emits no plugin flags.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-libdir }}/libacpp-clang.so")
endif()

# Which vector math library the host JIT uses. NOT discovery-derived: several
# may be present at once and discovery cannot choose between them. The default
# is the one every glibc system has, every code path compiles unconditionally,
# and the runtime falls back to libmvec when the configured library is absent.
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "libmvec")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-specific defaults
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "")
endif()

# The CPU backend is always built (upstream's WITH_CPU_BACKEND is
# unconditionally true), so the omp flows have no vendor unit: this is
# core, not a vendor file. The link line and flags are the platform's,
# which is why they live here rather than matrix-wide; the omp link line
# carries no rpath to libomp: under the omp flows the application's own
# link binds libomp, so the RUNPATH is the application builder's. Upstream's
# DEFAULT_OMP_FLAG has no APPLE special case outside macOS, so this needs no
# branch by build mode.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
