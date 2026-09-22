# HPC SDK runtime options - linux, every architecture.
#
# Include after core.cmake, only when the nvcxx compilation flow is enabled;
# the helpers and the strategy control live in core. The HPC SDK is a
# separate product from the CUDA toolkit with its own terms and lifecycle,
# so its runtime is its own vendor unit.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

# Where the HPC SDK redistributable runtime lands.
acpp_require_relative(ACPP_NVHPC_DEPLOY_PATH)
if(NOT DEFINED ACPP_NVHPC_DEPLOY_PATH)
  set(ACPP_NVHPC_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/nvhpc")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_NVHPC_PATH
  ACPP_DISCOVERED_NVHPC_PREFIX "${ACPP_DISCOVERED_NVHPC_PREFIX}"
  "{{ nvhpc-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_NVHPC_PREFIX}" STREQUAL "")
  set(_acpp_nvhpc_abs_libdir "${ACPP_DISCOVERED_NVHPC_PREFIX}/${ACPP_DISCOVERED_NVHPC_LIBDIR}")
else()
  set(_acpp_nvhpc_abs_libdir "")
endif()

acpp_declare_provenance(ACPP_NVHPC_LIB_PATH
  ACPP_DISCOVERED_NVHPC_LIBDIR "${_acpp_nvhpc_abs_libdir}"
  "{{ nvhpc-deploy-path }}/{{ nvhpc-libdir }}")

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

# The nvc++ compiler itself is never inside a toolkit and never inside our
# tree; the driver resolves a bare name through PATH.
acpp_default_strategy_only(ACPP_NVCXX)
if(NOT DEFINED ACPP_NVCXX)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND NOT "${ACPP_DISCOVERED_NVHPC_NVCXX}" STREQUAL "")
    set(ACPP_NVCXX "${ACPP_DISCOVERED_NVHPC_NVCXX}")
  else()
    set(ACPP_NVCXX "nvc++")
  endif()
endif()

# -Mnorpath suppresses the RPATH nvc++ would stamp into the application,
# which names the SDK on the building machine; ours names the unit, which
# travels. nvc++ links cudart from the CUDA bundled inside the SDK, but at
# run time the application resolves the soname through our RUNPATH to the
# toolkit unit's copy, the one rt-backend-cuda was built against; the
# toolkit unit is always present for this flow because the backend is built
# against it, and when only the SDK is installed the toolkit unit simply is
# the SDK's bundled CUDA, pointed at through CUDAToolkit_ROOT.
if(NOT DEFINED ACPP_NVCXX_LINK_LINE)
  set(ACPP_NVCXX_LINK_LINE "-Mnorpath -Wl,-rpath={{ nvhpc-lib-path }} -Wl,-rpath={{ cuda-lib-path }}")
endif()
