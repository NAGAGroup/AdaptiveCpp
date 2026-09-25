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
# Where libomp.dll lands. libomp is declared unconditionally, in both build
# modes, by the common file (principle 3: an ordinary vendor unit, not a
# build-mode branch) - see its "OMP" section - and the application-config
# declaration this platform keeps regardless: Windows has no RUNPATH, so a
# deployed app's own AddDllDirectory call still needs to be told where
# libomp.dll landed.

# libomp's own vendor unit is declared unconditionally by the common file,
# but its application-config root is kept only here: Windows has no
# RUNPATH, so unlike Linux/macOS (where libomp is purely DT_NEEDED-linked
# and never read back by path) a deployed app's AddDllDirectory call still
# needs ACPP_APP_LIBOMP_INSTALL_ROOT to find libomp.dll at run time.
acpp_declare_vendor_app_root(LIBOMP libomp)

# No libnuma on Windows.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# Ownership, not deployment strategy, decides which shape these take; see
# linux/common/core.cmake's comment, unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  # Concrete now, not a {{ }} template: acpp_declare_owned_resource's
  # application side is written by configure_file, which resolves nothing.
  acpp_declare_owned_resource(DEVICE_CMPLR "${CMAKE_INSTALL_BINDIR}/clang++.exe")
  acpp_declare_owned_resource(LLC "${CMAKE_INSTALL_BINDIR}/llc.exe")
  acpp_declare_owned_resource(OPT "${CMAKE_INSTALL_BINDIR}/opt.exe")
  # The host JIT links COFF with lld-link.
  acpp_declare_owned_resource(LLD "${CMAKE_INSTALL_BINDIR}/lld-link.exe")
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "${CMAKE_INSTALL_LIBDIR}/clang/${LLVM_VERSION_MAJOR}/include")
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
acpp_declare_owned_resource(LLVMSPIRV "${CMAKE_INSTALL_BINDIR}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv.exe")

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
