# Core options - macos, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------
#
# LLVM has no deploy-path knob of its own any more: what toolchain mode
# builds follows cmake's own install directory under {{ acpp-root }}
# ({{ acpp-libdir }}) directly. In plugin mode LLVM is the machine's
# (rule 2): it is never bundled at all.
#
# Where libomp lands. In toolchain mode it is ours, beside the LLVM we
# build. In plugin mode it is a vendor plugin (rule 4), taking the same
# two-knob shape as any other vendor unit below.

# Where the deploy step writes application configurations under `default`,
# where nothing is copied and the application's tree holds none of our
# libraries. The default covers a user compiling for themselves; a
# distribution maintainer building in `default` mode points it at the system
# configuration directory.
#
# Deliberately NOT subject to acpp_require_relative: this is the one path
# meant to be absolute and to point outside the tree.
#
# macOS: ~/Library/Application Support is the per-user configuration root.
if(NOT DEFINED ACPP_DEFAULT_STRATEGY_APP_CFG_DIR)
  set(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$HOME/Library/Application Support/AdaptiveCpp/app-cfgs")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------
#
# LLVM and libomp split by ownership; see linux/common/core.cmake's comment,
# unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_declare_owned_provenance(ACPP_LLVM_PATH "{{ acpp-libdir }}")
  acpp_declare_owned_provenance(ACPP_LIBOMP_PATH "{{ acpp-libdir }}")
else()
  set(ACPP_LLVM_PATH "")
  acpp_declare_vendor_subdir(LIBOMP libomp)
  acpp_declare_vendor_root(LIBOMP libomp ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}")
  acpp_declare_vendor_app_root(LIBOMP libomp)
endif()

# No libnuma on macOS.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# The device compiler is used by the multipass flows AND by the generic JIT,
# which is exactly why it has two sides: the driver invokes it from the
# toolchain while compiling, the JIT invokes it from the deployment while an
# application runs, and those need not be the same binary.
#
# Ownership, not deployment strategy, decides which shape these take; see
# linux/common/core.cmake's comment, unchanged here.

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  # No {{ acpp-bindir }} entry exists on this platform (only Windows names
  # one): CMAKE_INSTALL_BINDIR is "bin" everywhere cmake's own GNU install
  # dirs apply, so the segment is written literally.
  acpp_declare_owned_resource(DEVICE_CMPLR "bin/clang++")
  acpp_declare_owned_resource(LLC "bin/llc")
  acpp_declare_owned_resource(OPT "bin/opt")
  # The host JIT links Mach-O with ld64.lld.
  acpp_declare_owned_resource(LLD "bin/ld64.lld")
  # clang's resource include directory. The JIT's HIP compilation needs it,
  # so it has two sides like the compiler itself.
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "{{ acpp-libdir }}/clang/{{ llvm-version-major }}/include")
else()
  acpp_declare_machine_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}")
  acpp_declare_machine_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc")
  acpp_declare_machine_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt")
  acpp_declare_machine_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/ld64.lld")
  acpp_declare_machine_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}")
endif()

# llvm-spirv is not LLVM's: AdaptiveCpp builds its own fork of the
# SPIRV-LLVM-Translator and installs it under its own library directory
# (doc/install-ocl.md), independent of cmake's own LLVM install dirs. Ours
# in BOTH modes (rule 1) - the machine's LLVM never supplies it, plugin or
# not - always the deploy-layout placeholder, in every strategy.
acpp_declare_owned_resource(LLVMSPIRV "{{ acpp-libdir }}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")

# No vector math libraries on macOS: upstream supports none for the JIT on
# this platform.

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# The host C++ compiler the driver invokes for CPU code. Ownership, not
# strategy, decides its shape; see linux/common/core.cmake's comment,
# unchanged here.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_CPU_CXX "{{ acpp-root }}/bin/clang++")
else()
  set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
endif()

# The compiler plugin, in plugin builds only. Ours, always the
# deploy-layout placeholder, no override - see linux's comment. When
# AdaptiveCpp is linked into the LLVM tools there is no plugin file and the
# driver emits no plugin flags. The driver currently hardcodes "lib" when
# building this path, which is wrong on any lib64 distribution; this entry
# is what those sites should read.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_PLUGIN_PATH "{{ acpp-root }}/{{ acpp-libdir }}/libacpp-clang.so")
endif()

# No vector math on macOS; the default is "none".
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "none")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-specific defaults
# ---------------------------------------------------------------------------

# Upstream's DEFAULT_OMP_FLAG: AppleClang needs -Xclang to pass -fopenmp
# through to the frontend. In toolchain mode we build our own clang, which
# is never AppleClang, so the flag is plain; in plugin mode the flag
# depends on CMAKE_CXX_COMPILER_ID, the machine's bootstrap compiler (the
# one AdaptiveCpp itself was built with) - upstream's exact rule, kept.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(_acpp_omp_flag "-fopenmp")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
  set(_acpp_omp_flag "-Xclang -fopenmp")
else()
  set(_acpp_omp_flag "-fopenmp")
endif()

# On macOS clang does not find libomp on its own, so the sequential link
# line names the directory. {{ libomp-path }} resolves per the ownership
# split above, so this one formula already covers both build modes.
if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "-L{{ libomp-path }} -lomp")
endif()

# The CPU backend is always built (upstream's WITH_CPU_BACKEND is
# unconditionally true), so the omp flows have no vendor unit: this is
# core, not a vendor file. On macOS clang does not find libomp on its own,
# so the omp link line names the directory too, unlike the other
# platforms; the multipass exemption still applies to rpath.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "${_acpp_omp_flag} -L{{ libomp-path }} -lomp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "${_acpp_omp_flag} -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
