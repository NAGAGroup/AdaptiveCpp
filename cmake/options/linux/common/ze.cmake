# Level Zero options - linux, every architecture.
#
# Include after core.cmake, only when the Level Zero backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the loader in the vendor's own library directory, nothing else.
# Two knobs (ACPP_ZE_SUBDIR plus the loader/header hints), everything else
# derived - see "Vendor units" in the common core file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(ZE ze)
acpp_declare_vendor_root(ZE ze ACPP_DISCOVERED_ZE_PREFIX "${ACPP_DISCOVERED_ZE_PREFIX}")

acpp_declare_vendor_subdir_fact(ZE RT ACPP_DISCOVERED_ZE_LIBDIR "${ACPP_DISCOVERED_ZE_LIBDIR}")
acpp_declare_vendor_app_subdir(ZE ze RT)

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time. Level Zero has no multipass flow; the driver passes
# nothing.
