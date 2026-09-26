# OMP (libomp) vendor install rule - linux, every architecture.
#
# See cmake/options/common/core.cmake, "OMP: an ordinary vendor, in both
# build modes", for what ACPP_LIBOMP_SOURCE_DIR/ACPP_LIBOMP_DISCOVERED_ROOT/
# ACPP_LIBOMP_NAME mean and why the SOURCE differs by build mode. No FACT:
# libomp is a single-library vendor unit with no internal lib/include/bin
# split (core.cmake's acpp_declare_vendor_app_root, not
# acpp_declare_vendor_app_dir).
#
# Toolchain mode installs nothing here: libomp is built by this same LLVM
# build and installed by LLVM itself into the prefix, which the toolchain
# config points at directly - so there is no dependency on LLVM's install
# running first.
#
# In plugin mode, ACPP_LIBOMP_DISCOVERED_ROOT is ACPP_DISCOVERED_LIBOMP_DIR
# (find_package(OpenMP) against the machine's own compiler), which already
# exists at configure time - the ordinary, immediate path.

if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_install_vendor_libs(STEM LIBOMP FACT "" NAMES "${ACPP_LIBOMP_NAME}")
endif()
