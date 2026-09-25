# NVHPC (HPC SDK redistributable runtime) vendor install rule - linux,
# every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. A
# no-op unless ACPP_NVHPC_SHIPPED. config/linux/common/deploy/nvhpc.json's
# sole external-nonpermissive row copies the whole RT subdir (files=["*"]):
# ACPP_DISCOVERED_NVHPC_PREFIX is already the SDK's REDIST root, so RT
# (compilers/lib under it) is the entire redistributable runtime, not a
# single library - no toolchain-only pieces beyond it (the compiler itself,
# nvc++, is never inside our tree - see cmake/options/linux/common/
# nvhpc.cmake).

acpp_install_vendor_dir(STEM NVHPC FACT "${ACPP_NVHPC_RT_SUBDIR}")
