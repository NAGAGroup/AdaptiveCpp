# Level Zero vendor install rule - windows, every architecture.
#
# See cmake/install/linux/common/ze.cmake for the shared reasoning. The
# DLL lives in the vendor's bin-relative directory, matching
# config/windows/common/deploy/ze.json's sole external-permissive row -
# there was no separate import-library row in the pre-2a manifest
# (`git show b7e8e562:config/windows/common/deploy/ze.json`) to carry
# forward as a toolchain-only piece, so this is the whole unit.

acpp_install_vendor_libs(STEM ZE FACT "${ACPP_ZE_BIN_SUBDIR}" NAMES ze_loader)
