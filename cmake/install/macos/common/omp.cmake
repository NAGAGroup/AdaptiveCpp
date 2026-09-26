# OMP (libomp) vendor install rule - macOS, every architecture.
#
# See cmake/install/linux/common/omp.cmake for the shared reasoning
# (ordinary-vendor-in-both-build-modes). Toolchain mode installs nothing
# here: libomp is built by this same LLVM build and installed by LLVM
# itself into the prefix, which the toolchain config points at directly -
# so there is no dependency on LLVM's install running first. No FACT:
# libomp is a single-library vendor unit with no internal lib/include/bin
# split. The resolver's macOS branch looks for "lib<name>*.dylib" under
# ACPP_LIBOMP_DISCOVERED_ROOT.

if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_install_vendor_libs(STEM LIBOMP FACT "" NAMES "${ACPP_LIBOMP_NAME}")
endif()
