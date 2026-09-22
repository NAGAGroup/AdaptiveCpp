# CUDA options - windows, aarch64.
#
# Include after core.cmake, only when the CUDA backend is enabled; the
# helpers and the strategy control live in core. The three kinds - deploy
# paths, provenance and resources - are the same as core's.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

# Where the CUDA vendor unit lands. On Windows a vendor unit's DLLs live in
# its bin-relative directory, so the unit deploys under the bin directory.
acpp_require_relative(ACPP_CUDA_DEPLOY_PATH)
if(NOT DEFINED ACPP_CUDA_DEPLOY_PATH)
  set(ACPP_CUDA_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/cuda")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_CUDA_PATH
  ACPP_DISCOVERED_CUDA_PREFIX "${ACPP_DISCOVERED_CUDA_PREFIX}"
  "{{ cuda-deploy-path }}")

# The library, include and binary directories inside the vendor unit.
if(NOT "${ACPP_DISCOVERED_CUDA_PREFIX}" STREQUAL "")
  set(_acpp_cuda_abs_libdir "${ACPP_DISCOVERED_CUDA_PREFIX}/${ACPP_DISCOVERED_CUDA_LIBDIR}")
  set(_acpp_cuda_abs_incdir "${ACPP_DISCOVERED_CUDA_PREFIX}/${ACPP_DISCOVERED_CUDA_INCDIR}")
  set(_acpp_cuda_abs_bindir "${ACPP_DISCOVERED_CUDA_PREFIX}/${ACPP_DISCOVERED_CUDA_BINDIR}")
else()
  set(_acpp_cuda_abs_libdir "")
  set(_acpp_cuda_abs_incdir "")
  set(_acpp_cuda_abs_bindir "")
endif()

acpp_declare_provenance(ACPP_CUDA_LIB_PATH
  ACPP_DISCOVERED_CUDA_LIBDIR "${_acpp_cuda_abs_libdir}"
  "{{ cuda-deploy-path }}/{{ cuda-libdir }}")

acpp_declare_provenance(ACPP_CUDA_INCLUDE_PATH
  ACPP_DISCOVERED_CUDA_INCDIR "${_acpp_cuda_abs_incdir}"
  "{{ cuda-deploy-path }}/{{ cuda-incdir }}")

acpp_declare_provenance(ACPP_CUDA_BIN_PATH
  ACPP_DISCOVERED_CUDA_BINDIR "${_acpp_cuda_abs_bindir}"
  "{{ cuda-deploy-path }}/{{ cuda-bindir }}")

# ---------------------------------------------------------------------------
# Resource - device bitcode and DLL directory
# ---------------------------------------------------------------------------

acpp_declare_resource(CUDA_LIBDEVICE_DIR
  ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}"
  "{{ cuda-deploy-path }}/nvvm/libdevice")

# Windows has no RUNPATH; the runtime's own AddDllDirectory is the Windows
# form of the derived RUNPATH and is fed from the application configuration,
# which is why this directory is two-sided here and single-sided provenance
# on Linux.
acpp_declare_resource(CUDA_DLL_DIR
  ACPP_DISCOVERED_CUDA_BINDIR "${_acpp_cuda_abs_bindir}"
  "{{ cuda-deploy-path }}/{{ cuda-bindir }}")

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_CUDA_LINK_LINE)
  set(ACPP_CUDA_LINK_LINE "-L{{ cuda-lib-path }} -lcudart")
endif()
if(NOT DEFINED ACPP_CUDA_CXX_FLAGS)
  set(ACPP_CUDA_CXX_FLAGS "-U__FLOAT128__ -U__SIZEOF_FLOAT128__ -isystem {{ toolchain-path }}/include/AdaptiveCpp/hipSYCL/std/hiplike")
endif()
