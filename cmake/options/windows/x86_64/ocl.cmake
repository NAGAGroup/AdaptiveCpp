# OpenCL options - windows, x86_64.
#
# Include after core.cmake, only when the OpenCL backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the ICD loader's DLL, nothing else. On Windows there is no
# multipass flow for OpenCL.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_OCL_DEPLOY_PATH)
if(NOT DEFINED ACPP_OCL_DEPLOY_PATH)
  set(ACPP_OCL_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/ocl")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_OCL_PATH
  ACPP_DISCOVERED_OCL_PREFIX "${ACPP_DISCOVERED_OCL_PREFIX}"
  "{{ ocl-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_OCL_PREFIX}" STREQUAL "")
  set(_acpp_ocl_abs_bindir "${ACPP_DISCOVERED_OCL_PREFIX}/${ACPP_DISCOVERED_OCL_BINDIR}")
else()
  set(_acpp_ocl_abs_bindir "")
endif()

acpp_declare_provenance(ACPP_OCL_BIN_PATH
  ACPP_DISCOVERED_OCL_BINDIR "${_acpp_ocl_abs_bindir}"
  "{{ ocl-deploy-path }}/{{ ocl-bindir }}")

# Nothing links the loader when driving; no multipass flow.

# ---------------------------------------------------------------------------
# Resource - DLL directory for AddDllDirectory
# ---------------------------------------------------------------------------
#
# Windows has no RUNPATH; the runtime's own AddDllDirectory is the Windows
# form of the derived RUNPATH and is fed from the application configuration,
# which is why this directory is two-sided here and single-sided provenance
# on Linux.

acpp_declare_resource(OCL_DLL_DIR
  ACPP_DISCOVERED_OCL_BINDIR "${_acpp_ocl_abs_bindir}"
  "{{ ocl-deploy-path }}/{{ ocl-bindir }}")
