# Level Zero options - linux, x86_64.
#
# Include after core.cmake, only when the Level Zero backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the loader in the vendor's own library directory, nothing else.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_ZE_DEPLOY_PATH)
if(NOT DEFINED ACPP_ZE_DEPLOY_PATH)
  set(ACPP_ZE_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/ze")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_ZE_PATH
  ACPP_DISCOVERED_ZE_PREFIX "${ACPP_DISCOVERED_ZE_PREFIX}"
  "{{ ze-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_ZE_PREFIX}" STREQUAL "")
  set(_acpp_ze_abs_libdir "${ACPP_DISCOVERED_ZE_PREFIX}/${ACPP_DISCOVERED_ZE_LIBDIR}")
else()
  set(_acpp_ze_abs_libdir "")
endif()

acpp_declare_provenance(ACPP_ZE_LIB_PATH
  ACPP_DISCOVERED_ZE_LIBDIR "${_acpp_ze_abs_libdir}"
  "{{ ze-deploy-path }}/{{ ze-libdir }}")

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time.

# Level Zero has no multipass flow; the driver passes nothing.
