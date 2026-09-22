# OpenCL options - linux, every architecture.
#
# Include after core.cmake, only when the OpenCL backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the ICD loader in the vendor's own library directory, nothing else.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_OCL_DEPLOY_PATH)
if(NOT DEFINED ACPP_OCL_DEPLOY_PATH)
  set(ACPP_OCL_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/ocl")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_OCL_PATH
  ACPP_DISCOVERED_OCL_PREFIX "${ACPP_DISCOVERED_OCL_PREFIX}"
  "{{ ocl-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_OCL_PREFIX}" STREQUAL "")
  set(_acpp_ocl_abs_libdir "${ACPP_DISCOVERED_OCL_PREFIX}/${ACPP_DISCOVERED_OCL_LIBDIR}")
else()
  set(_acpp_ocl_abs_libdir "")
endif()

acpp_declare_provenance(ACPP_OCL_LIB_PATH
  ACPP_DISCOVERED_OCL_LIBDIR "${_acpp_ocl_abs_libdir}"
  "{{ ocl-deploy-path }}/{{ ocl-libdir }}")

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time.

# OpenCL has no multipass flow; the driver passes nothing.
