# Core options - macos, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------

# Where the LLVM unit lands. AdaptiveCpp comes in two shapes, and this is
# the one options default that differs between them:
#
#   * linked into an LLVM toolchain we build - one prefix, one tree, and
#     LLVM's bin and lib sit at its root: "."
#   * a plugin added to an existing LLVM - the toolchain's own tree is ours
#     alone, so a bundled LLVM unit travels under our library directory
#
# A publisher whose tree differs overrides this; the knob describes the tree
# the publisher produces, and under `managed` - where the publisher assembles
# the tree themselves - the override states where the bundled items actually
# landed. LLVM travels whole either way: its binaries find libLLVM through
# their own RUNPATH, so the bin-to-libdir relationship has to survive the
# move.
acpp_require_relative(ACPP_LLVM_DEPLOY_PATH)
if(NOT DEFINED ACPP_LLVM_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LLVM_DEPLOY_PATH ".")
  else()
    set(ACPP_LLVM_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext")
  endif()
endif()

# Where libomp lands. It defaults to travelling with LLVM, because LLVM's own
# libomp is normally what we have.
acpp_require_relative(ACPP_LIBOMP_DEPLOY_PATH)
if(NOT DEFINED ACPP_LIBOMP_DEPLOY_PATH)
  set(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/{{ llvm-libdir }}")
endif()

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
# Under the placeholder strategies the toolchain's own tree already has the
# deployment's shape, so the source is our tree; under `default` it is
# wherever this build found the thing.

acpp_declare_provenance(ACPP_LLVM_PATH ACPP_DISCOVERED_LLVM_PREFIX "${ACPP_DISCOVERED_LLVM_PREFIX}" "{{ llvm-deploy-path }}")
acpp_declare_provenance(ACPP_LIBOMP_PATH ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}" "{{ libomp-deploy-path }}")

# No libnuma on macOS.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# The device compiler is used by the multipass flows AND by the generic JIT,
# which is exactly why it has two sides: the driver invokes it from the
# toolchain while compiling, the JIT invokes it from the deployment while an
# application runs, and those need not be the same binary.

acpp_declare_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}"
                      "{{ llvm-deploy-path }}/bin/clang++")
acpp_declare_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc"
                      "{{ llvm-deploy-path }}/bin/llc")
acpp_declare_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt"
                      "{{ llvm-deploy-path }}/bin/opt")
# The host JIT links Mach-O with ld64.lld.
acpp_declare_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/ld64.lld"
                      "{{ llvm-deploy-path }}/bin/ld64.lld")
acpp_declare_resource(LLVMSPIRV ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llvm-spirv"
                      "{{ llvm-deploy-path }}/bin/llvm-spirv")

# clang's resource include directory. The JIT's HIP compilation needs it, so
# it has two sides like the compiler itself.
acpp_declare_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}"
  "{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")

# No vector math libraries on macOS: upstream supports none for the JIT on
# this platform.

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# The host C++ compiler the driver invokes for CPU code. May be gcc, or
# anything else with an OpenMP implementation - it does not have to be clang.
# Driver-only, so it has no application side; but it takes the same shape,
# because under the placeholder strategies the publisher has undertaken to
# provide a complete toolchain and it makes no sense for the host compiler to
# come from somewhere else.
acpp_default_strategy_only(ACPP_CPU_CXX)
if(NOT DEFINED ACPP_CPU_CXX)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND CMAKE_CXX_COMPILER)
    set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
  else()
    set(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++")
  endif()
endif()

# The compiler plugin, in plugin builds only. When AdaptiveCpp is linked into
# the LLVM tools there is no plugin file and the driver emits no plugin flags.
# The driver currently hardcodes "lib" when building this path, which is wrong
# on any lib64 distribution; this entry is what those sites should read.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_default_strategy_only(ACPP_PLUGIN_PATH)
  if(NOT DEFINED ACPP_PLUGIN_PATH)
    set(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-libdir }}/libacpp-clang.so")
  endif()
endif()

# No vector math on macOS; the default is "none".
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "none")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-specific defaults
# ---------------------------------------------------------------------------

# On macOS clang does not find libomp on its own, so the sequential link
# line names the directory.
if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "-L{{ libomp-path }} -lomp")
endif()
