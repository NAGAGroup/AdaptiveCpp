# OMP (libomp) vendor install rule - linux, every architecture.
#
# See cmake/options/common/core.cmake, "OMP: an ordinary vendor, in both
# build modes", for what ACPP_LIBOMP_SOURCE_DIR/ACPP_LIBOMP_DISCOVERED_ROOT/
# ACPP_LIBOMP_NAME mean and why the SOURCE differs by build mode. No FACT:
# libomp is a single-library vendor unit with no internal lib/include/bin
# split (core.cmake's acpp_declare_vendor_app_root, not
# acpp_declare_vendor_app_dir).
#
# ORDERING (toolchain mode only): in toolchain mode,
# ACPP_LIBOMP_DISCOVERED_ROOT is this same build's own
# ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR} - the LLVM component
# build's own libdir - which does not exist yet at configure time and is
# only populated once LLVM's own install step has copied libomp into it.
# acpp_install_vendor_libs already handles this: when the source directory
# does not exist at configure time, it defers resolution into the
# install(CODE) block itself, which runs at `cmake --install` time. It is
# NOT guaranteed anywhere in this repository that LLVM's own install runs
# before this component's install(CODE) block does - install scripts run
# in the order cmake generated them across the whole build, which for an
# LLVM-component build is decided by that build's own add_subdirectory()
# order, outside this fork's control. If LLVM's install has not yet run,
# the deferred resolver's FATAL_ERROR names exactly what was missing and
# where, which is at least a clear failure rather than a silent no-op;
# arranging the ordering itself is unclaimed work, not done here.
#
# In plugin mode, ACPP_LIBOMP_DISCOVERED_ROOT is ACPP_DISCOVERED_LIBOMP_DIR
# (find_package(OpenMP) against the machine's own compiler), which already
# exists at configure time - the ordinary, immediate path.

acpp_install_vendor_libs(STEM LIBOMP FACT "" NAMES "${ACPP_LIBOMP_NAME}")
