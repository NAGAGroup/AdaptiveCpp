# Level Zero options - windows, every architecture.
#
# Include after core.cmake, only when the Level Zero backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the loader's DLL, nothing else. On Windows there is no
# multipass flow for Level Zero.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_ZE_DEPLOY_PATH)
if(NOT DEFINED ACPP_ZE_DEPLOY_PATH)
  set(ACPP_ZE_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ze")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_ZE_PATH
  ACPP_DISCOVERED_ZE_PREFIX "${ACPP_DISCOVERED_ZE_PREFIX}"
  "{{ ze-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_ZE_PREFIX}" STREQUAL "")
  set(_acpp_ze_abs_bindir "${ACPP_DISCOVERED_ZE_PREFIX}/${ACPP_DISCOVERED_ZE_BINDIR}")
else()
  set(_acpp_ze_abs_bindir "")
endif()

acpp_declare_provenance(ACPP_ZE_BIN_PATH
  ACPP_DISCOVERED_ZE_BINDIR "${_acpp_ze_abs_bindir}"
  "{{ ze-deploy-path }}/{{ ze-bindir }}")

# Nothing links the loader when driving; no multipass flow.

# ---------------------------------------------------------------------------
# Resource - DLL directory for AddDllDirectory
# ---------------------------------------------------------------------------
#
# Windows has no RUNPATH; the runtime's own AddDllDirectory is the Windows
# form of the derived RUNPATH and is fed from the application configuration,
# which is why this directory is two-sided here and single-sided provenance
# on Linux.

acpp_declare_resource(ZE_DLL_DIR
  ACPP_DISCOVERED_ZE_BINDIR "${_acpp_ze_abs_bindir}"
  "{{ ze-deploy-path }}/{{ ze-bindir }}")
