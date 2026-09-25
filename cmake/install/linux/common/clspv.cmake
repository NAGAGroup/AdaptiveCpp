# clspv vendor install rule - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. A
# no-op unless ACPP_CLSPV_SHIPPED. clspv is an executable the JIT invokes
# at application run time (cmake/options/linux/common/clspv.cmake's own
# header), not a shared library - PROGRAMS, not the libs helper - matching
# config/linux/common/deploy/clspv.json's sole external-permissive row.

acpp_install_vendor_files(STEM CLSPV FACT "${ACPP_CLSPV_BIN_SUBDIR}" PROGRAMS clspv)
