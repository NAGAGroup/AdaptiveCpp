# clspv options - macos, arm64.
#
# Include after core.cmake, only when the Vulkan backend is enabled; the
# helpers and the strategy control live in core. clspv is an executable the
# JIT invokes at application run time, so it is a two-sided resource: the
# driver invokes it from the toolchain while compiling, the JIT invokes it
# from the deployment while an application runs.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_CLSPV_DEPLOY_PATH)
if(NOT DEFINED ACPP_CLSPV_DEPLOY_PATH)
  set(ACPP_CLSPV_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/clspv")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_CLSPV_PATH
  ACPP_DISCOVERED_CLSPV_PREFIX "${ACPP_DISCOVERED_CLSPV_PREFIX}"
  "{{ clspv-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_CLSPV_PREFIX}" STREQUAL "")
  set(_acpp_clspv_abs_bindir "${ACPP_DISCOVERED_CLSPV_PREFIX}/${ACPP_DISCOVERED_CLSPV_BINDIR}")
else()
  set(_acpp_clspv_abs_bindir "")
endif()

acpp_declare_provenance(ACPP_CLSPV_BIN_PATH
  ACPP_DISCOVERED_CLSPV_BINDIR "${_acpp_clspv_abs_bindir}"
  "{{ clspv-deploy-path }}/{{ clspv-bindir }}")

# ---------------------------------------------------------------------------
# Resource - the clspv executable
# ---------------------------------------------------------------------------

# The JIT runs clspv from the deployment, which is why this directory is
# two-sided here.
if(NOT "${_acpp_clspv_abs_bindir}" STREQUAL "")
  set(_acpp_clspv_abs_exe "${_acpp_clspv_abs_bindir}/clspv")
else()
  set(_acpp_clspv_abs_exe "")
endif()
acpp_declare_resource(CLSPV
  ACPP_DISCOVERED_CLSPV_BINDIR "${_acpp_clspv_abs_exe}"
  "{{ clspv-deploy-path }}/{{ clspv-bindir }}/clspv")
