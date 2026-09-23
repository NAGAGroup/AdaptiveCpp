# OpenCL options - linux, every architecture.
#
# Include after core.cmake, only when the OpenCL backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the ICD loader in the vendor's own library directory, nothing
# else. Two knobs (ACPP_OCL_SUBDIR plus whatever OpenCL_LIBRARY steers
# discovery), everything else derived - see "Vendor units" in the common
# core file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(OCL ocl)
acpp_declare_vendor_root(OCL ocl ACPP_DISCOVERED_OCL_PREFIX "${ACPP_DISCOVERED_OCL_PREFIX}")

acpp_declare_vendor_subdir_fact(OCL RT ACPP_DISCOVERED_OCL_LIBDIR "${ACPP_DISCOVERED_OCL_LIBDIR}")
acpp_declare_vendor_app_subdir(OCL ocl RT)

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time. OpenCL has no multipass flow; the driver passes nothing.
