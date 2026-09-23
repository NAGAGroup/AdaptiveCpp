# Level Zero options - windows, every architecture.
#
# Include after core.cmake, only when the Level Zero backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the loader's DLL, nothing else. On Windows there is no multipass
# flow for Level Zero. Two knobs (ACPP_ZE_SUBDIR plus the loader/header
# hints), everything else derived - see "Vendor units" in the common core
# file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(ZE ze)
acpp_declare_vendor_root(ZE ze ACPP_DISCOVERED_ZE_PREFIX "${ACPP_DISCOVERED_ZE_PREFIX}")

# BIN is the DLL directory Windows feeds AddDllDirectory through - Windows
# has no RUNPATH, so this is the two-sided directory a deployed
# application's own configuration must carry, unlike Linux's single-sided
# provenance.
acpp_declare_vendor_subdir_fact(ZE BIN ACPP_DISCOVERED_ZE_BINDIR "${ACPP_DISCOVERED_ZE_BINDIR}")
acpp_declare_vendor_app_subdir(ZE ze BIN)

# Nothing links the loader when driving; no multipass flow.
