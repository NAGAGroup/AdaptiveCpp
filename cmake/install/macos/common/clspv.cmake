# clspv vendor install rule - macOS, every architecture.
#
# See cmake/install/linux/common/clspv.cmake for the shared reasoning.
# Same shape as linux, matching config/macos/common/deploy/clspv.json.

acpp_install_vendor_files(STEM CLSPV FACT "${ACPP_CLSPV_BIN_SUBDIR}" PROGRAMS clspv)
