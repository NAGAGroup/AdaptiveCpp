# Core options - windows, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------

# Where the LLVM unit lands. Windows toolchains are linked into LLVM
# (installing.md); the plugin branch is kept only for shape.
acpp_require_relative(ACPP_LLVM_DEPLOY_PATH)
if(NOT DEFINED ACPP_LLVM_DEPLOY_PATH)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LLVM_DEPLOY_PATH ".")
  else()
    set(ACPP_LLVM_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext")
  endif()
endif()

# Where libomp.dll lands. On Windows it is in LLVM's bin directory.
acpp_require_relative(ACPP_LIBOMP_DEPLOY_PATH)
if(NOT DEFINED ACPP_LIBOMP_DEPLOY_PATH)
  set(ACPP_LIBOMP_DEPLOY_PATH "{{ llvm-deploy-path }}/bin")
endif()

# Where the deploy step writes application configurations under `default`.
if(NOT DEFINED ACPP_DEFAULT_STRATEGY_APP_CFG_DIR)
  set(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$LOCALAPPDATA/AdaptiveCpp/app-cfgs")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_LLVM_PATH ACPP_DISCOVERED_LLVM_PREFIX "${ACPP_DISCOVERED_LLVM_PREFIX}" "{{ llvm-deploy-path }}")
acpp_declare_provenance(ACPP_LIBOMP_PATH ACPP_DISCOVERED_LIBOMP_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}" "{{ libomp-deploy-path }}")

# No libnuma on Windows.

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------

acpp_declare_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}"
                      "{{ llvm-deploy-path }}/bin/clang++.exe")
acpp_declare_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc.exe"
                      "{{ llvm-deploy-path }}/bin/llc.exe")
acpp_declare_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt.exe"
                      "{{ llvm-deploy-path }}/bin/opt.exe")
# The host JIT links COFF with lld-link.
acpp_declare_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/lld-link.exe"
                      "{{ llvm-deploy-path }}/bin/lld-link.exe")
acpp_declare_resource(LLVMSPIRV ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llvm-spirv.exe"
                      "{{ llvm-deploy-path }}/bin/llvm-spirv.exe")

# clang's resource include directory.
acpp_declare_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}"
  "{{ llvm-deploy-path }}/{{ llvm-libdir }}/clang/{{ llvm-version-major }}/include")

# No vector math libraries on Windows: upstream supports no vector math
# library for the JIT on this platform.

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

acpp_default_strategy_only(ACPP_CPU_CXX)
if(NOT DEFINED ACPP_CPU_CXX)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND CMAKE_CXX_COMPILER)
    set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
  else()
    set(ACPP_CPU_CXX "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++.exe")
  endif()
endif()

# The compiler plugin, in plugin builds only. Windows toolchains are
# linked-only (installing.md) so the branch is kept only for shape.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_default_strategy_only(ACPP_PLUGIN_PATH)
  if(NOT DEFINED ACPP_PLUGIN_PATH)
    set(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ acpp-bindir }}/acpp-clang.dll")
  endif()
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
# core, not a vendor file. The link line and flags are the platform's,
# which is why they live here rather than matrix-wide; the omp link line
# carries no rpath to libomp: under the omp flows the application's own
# link binds libomp, so the RUNPATH is the application builder's.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
