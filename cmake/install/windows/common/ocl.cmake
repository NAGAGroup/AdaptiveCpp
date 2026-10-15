# OpenCL vendor install rule - windows, every architecture.
#
# See cmake/install/linux/common/ocl.cmake for the shared reasoning. The
# DLL lives in the vendor's bin-relative directory, matching
# config/windows/common/deploy/ocl.json's sole ocl row; there is no separate
# toolchain-only import-library piece.

acpp_install_vendor_libs(STEM OCL FACT "${ACPP_OCL_BIN_SUBDIR}" NAMES OpenCL)
