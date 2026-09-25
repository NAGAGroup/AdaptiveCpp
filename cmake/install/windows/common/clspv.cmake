# clspv vendor install rule - windows, every architecture.
#
# See cmake/install/linux/common/clspv.cmake for the shared reasoning, with
# the .exe suffix, matching config/windows/common/deploy/clspv.json
# (["clspv.exe"]) and cmake/options/windows/common/clspv.cmake's own
# ACPP_TOOLCHAIN_CLSPV/ACPP_APP_CLSPV, which both name "clspv.exe" too.

acpp_install_vendor_files(STEM CLSPV FACT "${ACPP_CLSPV_BIN_SUBDIR}" PROGRAMS clspv.exe)
