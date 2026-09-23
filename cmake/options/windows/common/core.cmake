# Core options - windows, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------

# Where the LLVM unit lands, in toolchain mode only - LLVM is ours there
# (rule 1). Windows toolchains are linked into LLVM (installing.md); the
# plugin branch is kept only for shape, and empty rather than a bundled
# path, because plugin mode never bundles LLVM (rule 2).
acpp_require_relative(ACPP_LLVM_DEPLOY_PATH)
if(NOT DEFINED ACPP_LLVM_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LLVM_DEPLOY_PATH ".")
  else()
    set(ACPP_LLVM_DEPLOY_PATH "")
  endif()
endif()

# Where libomp.dll lands. In toolchain mode it is ours, in LLVM's bin
# directory. In plugin mode it is a vendor plugin (rule 4), deploying
# beside our own binaries like any other vendor DLL, governed by
# ACPP_DEPLOYMENT_STRATEGY.
acpp_require_relative(ACPP_LIBOMP_DEPLOY_PATH)
if(NOT DEFINED ACPP_LIBOMP_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/bin")
  else()
    set(ACPP_LIBOMP_DEPLOY_PATH "{{ acpp-bindir }}")
  endif()
endif()

# Where the deploy step writes application configurations under `default`.
if(NOT DEFINED ACPP_DEFAULT_STRATEGY_APP_CFG_DIR)
  set(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$LOCALAPPDATA/AdaptiveCpp/app-cfgs")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------
#
# LLVM and libomp split by ownership; see linux/common/core.cmake's comment,
# unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_provenance(ACPP_LLVM_PATH "{{ llvm-deploy-path }}")
  acpp_declare_owned_provenance(ACPP_LIBOMP_PATH "{{ libomp-deploy-path }}")
else()
  set(ACPP_LLVM_PATH "")
  acpp_declare_provenance(ACPP_LIBOMP_PATH ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}" "{{ libomp-deploy-path }}")
endif()

# No libnuma on Windows.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# Ownership, not deployment strategy, decides which shape these take; see
# linux/common/core.cmake's comment, unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_resource(DEVICE_CMPLR "{{ llvm-deploy-path }}/bin/clang++.exe")
  acpp_declare_owned_resource(LLC "{{ llvm-deploy-path }}/bin/llc.exe")
  acpp_declare_owned_resource(OPT "{{ llvm-deploy-path }}/bin/opt.exe")
  # The host JIT links COFF with lld-link.
  acpp_declare_owned_resource(LLD "{{ llvm-deploy-path }}/bin/lld-link.exe")
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")
else()
  acpp_declare_machine_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}")
  acpp_declare_machine_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc.exe")
  acpp_declare_machine_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt.exe")
  acpp_declare_machine_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/lld-link.exe")
  acpp_declare_machine_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}")
endif()

# llvm-spirv is not LLVM's: AdaptiveCpp builds its own fork of the
# SPIRV-LLVM-Translator and installs it under its own directory
# (doc/install-ocl.md), independent of {{ llvm-deploy-path }}. Ours in
# BOTH modes (rule 1) - the machine's LLVM never supplies it, plugin or
# not - always the deploy-layout placeholder, in every strategy.
acpp_declare_owned_resource(LLVMSPIRV "{{ acpp-bindir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv.exe")

# No vector math libraries on Windows: upstream supports no vector math
# library for the JIT on this platform.

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# Ownership, not strategy, decides cpu-cxx's shape; see linux's comment.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++.exe")
else()
  set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
endif()

# The compiler plugin, in plugin builds only. Windows toolchains are
# linked-only (installing.md) so the branch is kept only for shape; ours,
# always the deploy-layout placeholder, no override - see linux's comment.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-bindir }}/acpp-clang.dll")
endif()

# No vector math on Windows; the default is "none".
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "none")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-specific defaults
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "-llibomp")
endif()

# The CPU backend is always built (upstream's WITH_CPU_BACKEND is
# unconditionally true), so the omp flows have no vendor unit: this is
# core, not a vendor file. Upstream's DEFAULT_OMP_FLAG has no APPLE special
# case outside macOS, so this needs no branch by build mode.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
