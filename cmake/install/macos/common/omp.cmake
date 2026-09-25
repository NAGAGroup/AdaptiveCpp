# OMP (libomp) vendor install rule - macOS, every architecture.
#
# See cmake/install/linux/common/omp.cmake for the shared reasoning
# (ordinary-vendor-in-both-build-modes, the toolchain-mode ordering caveat
# against LLVM's own install). No FACT: libomp is a single-library vendor
# unit with no internal lib/include/bin split. The resolver's macOS branch
# looks for "lib<name>*.dylib" under ACPP_LIBOMP_DISCOVERED_ROOT.

acpp_install_vendor_libs(STEM LIBOMP FACT "" NAMES "${ACPP_LIBOMP_NAME}")
