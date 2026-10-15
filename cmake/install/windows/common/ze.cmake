# Level Zero vendor install rule - windows, every architecture.
#
# See cmake/install/linux/common/ze.cmake for the shared reasoning. The
# DLL lives in the vendor's bin-relative directory, matching
# config/windows/common/deploy/ze.json's sole ze row; there is no separate
# toolchain-only import-library piece.

acpp_install_vendor_libs(STEM ZE FACT "${ACPP_ZE_BIN_SUBDIR}" NAMES ze_loader)
