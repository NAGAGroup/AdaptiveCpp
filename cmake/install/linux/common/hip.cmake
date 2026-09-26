# HIP vendor install rules - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning and
# cmake/acpp-vendor-install.cmake for the helpers. A no-op unless
# ACPP_HIP_SHIPPED. Rows taken from config/linux/common/deploy/hip.json's
# external-permissive group (RT libs, SYSDEPS, BITCODE) plus the
# toolchain-only INCLUDE row recorded in /tmp/acpp-toolchain-only-rows.txt
# at the 2a split (headers, never deployed with an application).
#
#   RT       - three libraries every ROCm distribution ships (amdhip64,
#              hsa-runtime64, amd_comgr), plus four only some versions ship
#              (hiprtc, hiprtc-builtins, rocprofiler-register, rocm-core) -
#              OPTIONAL, so a distribution missing one still installs.
#   SYSDEPS  - the whole rocm_sysdeps tree libhsa-runtime64/libamdhip64
#              DT_NEED through their own $ORIGIN-relative RUNPATH; TheRock
#              only - skipped entirely where discovery found no such tree
#              (classic ROCm).
#   BITCODE  - the whole device bitcode tree (ockl.bc et al.); ditto.
#   INCLUDE  - the whole HIP C++ header tree; toolchain-only, the manifest
#              never deploys headers.

acpp_install_vendor_libs(STEM HIP FACT "${ACPP_HIP_RT_SUBDIR}"
  NAMES amdhip64 hsa-runtime64 amd_comgr)
acpp_install_vendor_libs(STEM HIP FACT "${ACPP_HIP_RT_SUBDIR}" OPTIONAL
  NAMES hiprtc hiprtc-builtins rocprofiler-register rocm-core)
if(NOT "${ACPP_HIP_SYSDEPS_SUBDIR}" STREQUAL "")
  acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_SYSDEPS_SUBDIR}")
endif()
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_BITCODE_SUBDIR}")
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_INCLUDE_SUBDIR}")
