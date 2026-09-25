# CUDA vendor install rules - windows, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. The
# Windows shape differs per doc/configuration-model.md's "Windows" section:
# the DLL lives in the vendor's bin-relative directory (deployable, same as
# the manifest's own "SHARED_LIB:cudart64_{{ cuda-version-major }}" row,
# which sits at cuda-bin-subdir on Windows - not cuda-rt-subdir, unlike
# Linux), the import library in the lib-relative directory (toolchain-only,
# RT - needed only to link the multipass flow's own tools, never deployed).
#
# The DLL is named "cudart64_<major>" with no extension:
# acpp_install_vendor_libs's resolver appends ".dll" on Windows itself, the
# same way it prepends "lib" and appends ".so*"/".dylib*" on the other
# platforms - <major> is discovery's own ACPP_DISCOVERED_CUDA_VERSION_MAJOR,
# so this line always names the version of CUDA that was actually found.

acpp_install_vendor_libs(STEM CUDA FACT "${ACPP_CUDA_BIN_SUBDIR}" NAMES "cudart64_${ACPP_DISCOVERED_CUDA_VERSION_MAJOR}")
acpp_install_vendor_files(STEM CUDA FACT "${ACPP_CUDA_RT_SUBDIR}" FILES cudart.lib)
acpp_install_vendor_files(STEM CUDA FACT "${ACPP_CUDA_LIBDEVICE_SUBDIR}" FILES libdevice.10.bc)
acpp_install_vendor_dir(STEM CUDA FACT "${ACPP_CUDA_INCLUDE_SUBDIR}")
acpp_install_vendor_files(STEM CUDA FACT "${ACPP_CUDA_BIN_SUBDIR}" PROGRAMS ptxas.exe fatbinary.exe)
