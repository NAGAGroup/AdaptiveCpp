# CUDA vendor install rules - linux, every architecture.
#
# Included from the root CMakeLists.txt after cmake/options/linux/<arch>/
# cuda.cmake (ACPP_CUDA_* already declared) and cmake/acpp-vendor-install.cmake
# (the helpers). Every call below is a no-op unless ACPP_CUDA_SHIPPED - see
# cmake/acpp-vendor-install.cmake's own header for what "shipped" installs
# and why this list is written by hand rather than derived from
# config/linux/common/deploy/cuda.json.
#
# Four groups, one per subdir fact discovery found:
#   RT        - libcudart, the runtime library the manifest also deploys.
#   LIBDEVICE - libdevice.10.bc, ditto.
#   INCLUDE   - the whole CUDA C++ header tree; toolchain-only, the
#               manifest never deploys headers.
#   BIN       - ptxas and fatbinary, the nvcc-adjacent tools the multipass
#               flow drives; toolchain-only, never deployed.

acpp_install_vendor_libs(STEM CUDA FACT "${ACPP_CUDA_RT_SUBDIR}" NAMES cudart)
acpp_install_vendor_files(STEM CUDA FACT "${ACPP_CUDA_LIBDEVICE_SUBDIR}" FILES libdevice.10.bc)
acpp_install_vendor_dir(STEM CUDA FACT "${ACPP_CUDA_INCLUDE_SUBDIR}")
acpp_install_vendor_files(STEM CUDA FACT "${ACPP_CUDA_BIN_SUBDIR}" PROGRAMS ptxas fatbinary)
