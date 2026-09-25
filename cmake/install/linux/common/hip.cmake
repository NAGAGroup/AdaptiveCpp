# HIP vendor install rules - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning and
# cmake/acpp-vendor-install.cmake for the helpers. A no-op unless
# ACPP_HIP_SHIPPED. Rows taken from config/linux/common/deploy/hip.json's
# external-permissive group (RT libs, SYSDEPS, BITCODE) plus the
# toolchain-only INCLUDE row recorded in /tmp/acpp-toolchain-only-rows.txt
# at the 2a split (headers, never deployed with an application).
#
#   RT       - the seven ROCm runtime libraries the manifest also deploys.
#   SYSDEPS  - the whole rocm_sysdeps tree libhsa-runtime64/libamdhip64
#              DT_NEED through their own $ORIGIN-relative RUNPATH; ditto.
#   BITCODE  - the whole device bitcode tree (ockl.bc et al.); ditto.
#   INCLUDE  - the whole HIP C++ header tree; toolchain-only, the manifest
#              never deploys headers.

acpp_install_vendor_libs(STEM HIP FACT "${ACPP_HIP_RT_SUBDIR}"
  NAMES amdhip64 hsa-runtime64 amd_comgr hiprtc hiprtc-builtins rocprofiler-register rocm-core)
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_SYSDEPS_SUBDIR}")
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_BITCODE_SUBDIR}")
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_INCLUDE_SUBDIR}")
