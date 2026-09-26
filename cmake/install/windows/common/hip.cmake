# HIP vendor install rules - windows, x86_64 (AMD's HIP SDK ships for
# x86_64 only, no aarch64 unit exists).
#
# See cmake/install/windows/common/cuda.cmake for the shared reasoning and
# cmake/acpp-vendor-install.cmake for the helpers. A no-op unless
# ACPP_HIP_SHIPPED. Rows taken from config/windows/common/deploy/hip.json's
# external-permissive group (the SDK's DLLs, BITCODE) plus the
# toolchain-only import library and header tree, never deployed with an
# application.
#
#   RT       - amdhip64.lib, the import library the multipass flow's own
#              tools link; toolchain-only, the manifest deploys the DLL
#              itself, at BIN, not the import library.
#   BIN      - the SDK's own DLLs: amdhip64/amd_comgr (every version
#              ships them, required), hiprtc/hiprtc-builtins (OPTIONAL -
#              an empty name, when a distribution lacks one, drops out of
#              the NAMES list by itself).
#   BITCODE  - the whole device bitcode tree (ockl.bc et al.); ditto.
#   INCLUDE  - the whole HIP C++ header tree; toolchain-only, the manifest
#              never deploys headers.

acpp_install_vendor_libs(STEM HIP FACT "${ACPP_HIP_BIN_SUBDIR}" NAMES "${ACPP_HIP_AMDHIP_DLL}" "${ACPP_HIP_COMGR_DLL}")
acpp_install_vendor_libs(STEM HIP FACT "${ACPP_HIP_BIN_SUBDIR}" OPTIONAL NAMES "${ACPP_HIP_HIPRTC_DLL}" "${ACPP_HIP_HIPRTC_BUILTINS_DLL}")
acpp_install_vendor_files(STEM HIP FACT "${ACPP_HIP_RT_SUBDIR}" FILES amdhip64.lib)
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_BITCODE_SUBDIR}")
acpp_install_vendor_dir(STEM HIP FACT "${ACPP_HIP_INCLUDE_SUBDIR}")
