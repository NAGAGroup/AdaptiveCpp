# OpenCL options - windows, every architecture.
#
# Include after core.cmake, only when the OpenCL backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the ICD loader's DLL, nothing else. On Windows there is no
# multipass flow for OpenCL. Two knobs (ACPP_OCL_SUBDIR plus the loader
# hints), everything else derived - see "Vendor units" in the common core
# file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(OCL ocl)
acpp_declare_vendor_root(OCL ocl ACPP_DISCOVERED_OCL_PREFIX "${ACPP_DISCOVERED_OCL_PREFIX}")

# BIN is the DLL directory Windows feeds AddDllDirectory through - Windows
# has no RUNPATH, so this is the two-sided directory a deployed
# application's own configuration must carry, unlike Linux's single-sided
# provenance.
acpp_declare_vendor_subdir_fact(OCL BIN ACPP_DISCOVERED_OCL_BINDIR "${ACPP_DISCOVERED_OCL_BINDIR}")
acpp_declare_vendor_app_dir(OCL ocl BIN)

# Nothing links the loader when driving; no multipass flow.
