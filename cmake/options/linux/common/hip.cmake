# HIP options - linux, every architecture.
#
# Include after core.cmake, only when the HIP backend is enabled; the
# helpers and the strategy control live in core. The three kinds - deploy
# paths, provenance and resources - are the same as core's.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

# Where the HIP vendor unit lands. Unlike LLVM, this is never the prefix
# itself, so there is no mode branch.
acpp_require_relative(ACPP_HIP_DEPLOY_PATH)
if(NOT DEFINED ACPP_HIP_DEPLOY_PATH)
  set(ACPP_HIP_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/hip")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_HIP_PATH
  ACPP_DISCOVERED_HIP_PREFIX "${ACPP_DISCOVERED_HIP_PREFIX}"
  "{{ hip-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_HIP_PREFIX}" STREQUAL "")
  set(_acpp_hip_abs_libdir "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_LIBDIR}")
  set(_acpp_hip_abs_incdir "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_INCDIR}")
else()
  set(_acpp_hip_abs_libdir "")
  set(_acpp_hip_abs_incdir "")
endif()

acpp_declare_provenance(ACPP_HIP_LIB_PATH
  ACPP_DISCOVERED_HIP_LIBDIR "${_acpp_hip_abs_libdir}"
  "{{ hip-deploy-path }}/{{ hip-libdir }}")

acpp_declare_provenance(ACPP_HIP_INCLUDE_PATH
  ACPP_DISCOVERED_HIP_INCDIR "${_acpp_hip_abs_incdir}"
  "{{ hip-deploy-path }}/{{ hip-incdir }}")

# The vendored system dependencies. libhsa-runtime64 and libamdhip64 DT_NEED
# librocm_sysdeps_* through their own $ORIGIN/rocm_sysdeps/lib RUNPATH;
# keeping the relative position keeps that RUNPATH true.
if(NOT "${_acpp_hip_abs_libdir}" STREQUAL "")
  set(_acpp_hip_abs_sysdeps "${_acpp_hip_abs_libdir}/rocm_sysdeps/lib")
else()
  set(_acpp_hip_abs_sysdeps "")
endif()
acpp_declare_provenance(ACPP_HIP_SYSDEPS_PATH
  ACPP_DISCOVERED_HIP_LIBDIR "${_acpp_hip_abs_sysdeps}"
  "{{ hip-deploy-path }}/{{ hip-libdir }}/rocm_sysdeps/lib")

# ---------------------------------------------------------------------------
# Resource - the one thing the JIT reads at run time
# ---------------------------------------------------------------------------

# Device bitcode directory. The directory is target-neutral; the ISA-specific
# file is chosen at run time.
if(NOT "${ACPP_DISCOVERED_HIP_PREFIX}" STREQUAL "")
  set(_acpp_hip_abs_bitcode "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_BITCODE_DIR}")
else()
  set(_acpp_hip_abs_bitcode "")
endif()

acpp_declare_resource(HIP_DEVICE_LIBS_DIR
  ACPP_DISCOVERED_HIP_BITCODE_DIR "${_acpp_hip_abs_bitcode}"
  "{{ hip-deploy-path }}/{{ hip-bitcode-dir }}")

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_HIP_LINK_LINE)
  set(ACPP_HIP_LINK_LINE "-Wl,-rpath={{ hip-lib-path }} -L{{ hip-lib-path }} -lamdhip64")
endif()

if(NOT DEFINED ACPP_HIP_CXX_FLAGS)
  set(ACPP_HIP_CXX_FLAGS "-isystem {{ toolchain-path }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-include-path }} --rocm-device-lib-path={{ hip-device-libs-dir }} --rocm-path={{ hip-path }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")
endif()
