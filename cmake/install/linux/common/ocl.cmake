# OpenCL vendor install rule - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. A
# no-op unless ACPP_OCL_SHIPPED. A loader-only unit: the ICD loader is the
# whole thing (config/linux/common/deploy/ocl.json's sole
# external-permissive row); no toolchain-only pieces (no headers ship - the
# fetched Khronos headers, cmake/fetch.cmake, are build-only and unrelated
# to this vendor unit).

acpp_install_vendor_libs(STEM OCL FACT "${ACPP_OCL_RT_SUBDIR}" NAMES OpenCL)
