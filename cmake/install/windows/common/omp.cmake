# OMP (libomp) vendor install rule - windows, every architecture.
#
# See cmake/install/linux/common/omp.cmake for the shared reasoning
# (ordinary-vendor-in-both-build-modes, the toolchain-mode ordering caveat
# against LLVM's own install). No FACT: libomp is a single-library vendor
# unit with no internal lib/include/bin split. The resolver checks both
# "<name>.dll" and "lib<name>.dll" under ACPP_LIBOMP_DISCOVERED_ROOT, so
# ACPP_LIBOMP_NAME's default of "omp" finds LLVM's actual "libomp.dll"
# without needing the "lib" prefix baked into the option itself.

acpp_install_vendor_libs(STEM LIBOMP FACT "" NAMES "${ACPP_LIBOMP_NAME}")
