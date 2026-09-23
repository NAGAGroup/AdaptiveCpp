# Core options - windows, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------
#
# LLVM has no deploy-path knob of its own any more: what toolchain mode
# builds follows cmake's own install directory under {{ acpp-root }}
# ({{ acpp-bindir }}) directly. Windows toolchains are linked into LLVM
# (installing.md); the plugin branches below are kept only for shape,
# because plugin mode never bundles LLVM (rule 2).
#
# Where libomp.dll lands. In toolchain mode it is ours, in {{ acpp-bindir }}
# beside the LLVM we build. In plugin mode it is a vendor plugin (rule 4),
# taking the same two-knob shape as any other vendor unit below.

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
  acpp_declare_owned_provenance(ACPP_LLVM_PATH "{{ acpp-bindir }}")
  acpp_declare_owned_provenance(ACPP_LIBOMP_PATH "{{ acpp-bindir }}")
else()
  set(ACPP_LLVM_PATH "")
  acpp_declare_vendor_subdir(LIBOMP libomp)
  acpp_declare_vendor_root(LIBOMP libomp ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}")
  acpp_declare_vendor_app_root(LIBOMP libomp)
endif()

# No libnuma on Windows.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# Ownership, not deployment strategy, decides which shape these take; see
# linux/common/core.cmake's comment, unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_resource(DEVICE_CMPLR "{{ acpp-bindir }}/clang++.exe")
  acpp_declare_owned_resource(LLC "{{ acpp-bindir }}/llc.exe")
  acpp_declare_owned_resource(OPT "{{ acpp-bindir }}/opt.exe")
  # The host JIT links COFF with lld-link.
  acpp_declare_owned_resource(LLD "{{ acpp-bindir }}/lld-link.exe")
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "{{ acpp-libdir }}/clang/{{ llvm-version-major }}/include")
else()
  acpp_declare_machine_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}")
  acpp_declare_machine_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc.exe")
  acpp_declare_machine_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt.exe")
  acpp_declare_machine_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/lld-link.exe")
  acpp_declare_machine_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}")
endif()

# llvm-spirv is not LLVM's: AdaptiveCpp builds its own fork of the
# SPIRV-LLVM-Translator and installs it under its own directory
# (doc/install-ocl.md), independent of cmake's own LLVM install dirs. Ours
# in BOTH modes (rule 1) - the machine's LLVM never supplies it, plugin or
# not - always the deploy-layout placeholder, in every strategy.
acpp_declare_owned_resource(LLVMSPIRV "{{ acpp-bindir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv.exe")

# No vector math libraries on Windows: upstream supports no vector math
# library for the JIT on this platform.

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# Ownership, not strategy, decides cpu-cxx's shape; see linux's comment.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_CPU_CXX "{{ acpp-root }}/{{ acpp-bindir }}/clang++.exe")
else()
  set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
endif()

# The compiler plugin, in plugin builds only. Windows toolchains are
# linked-only (installing.md) so the branch is kept only for shape; ours,
# always the deploy-layout placeholder, no override - see linux's comment.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_PLUGIN_PATH "{{ acpp-root }}/{{ acpp-bindir }}/acpp-clang.dll")
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
