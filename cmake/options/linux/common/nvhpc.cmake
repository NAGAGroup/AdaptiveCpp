# HPC SDK runtime options - linux, every architecture.
#
# Include after core.cmake, only when the nvcxx compilation flow is enabled;
# the helpers and the strategy control live in core. The HPC SDK is a
# separate product from the CUDA toolkit with its own terms and lifecycle,
# so its redistributable runtime is its own vendor unit - two knobs
# (ACPP_NVHPC_SUBDIR plus nvc++ being found on PATH), everything else
# derived - see "Vendor units" in the common core file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# The install subdir knob and the root it derives
# ---------------------------------------------------------------------------
#
# ACPP_DISCOVERED_NVHPC_PREFIX is already the SDK's REDIST root
# (<sdk-root>/REDIST), not the SDK root itself: the redistributable runtime
# is the vendor unit here, not the compiler.

acpp_declare_vendor(NVHPC nvhpc nonpermissive)
acpp_declare_vendor_root(NVHPC nvhpc ACPP_DISCOVERED_NVHPC_PREFIX "${ACPP_DISCOVERED_NVHPC_PREFIX}")

# ---------------------------------------------------------------------------
# Subdirs inside the vendor unit - discovery's own relative facts
# ---------------------------------------------------------------------------

acpp_declare_vendor_subdir_fact(NVHPC RT ACPP_DISCOVERED_NVHPC_LIBDIR "${ACPP_DISCOVERED_NVHPC_LIBDIR}")
acpp_declare_vendor_app_dir(NVHPC nvhpc RT)

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

# The nvc++ compiler itself is never inside a toolkit and never inside our
# tree; the driver resolves a bare name through PATH. No -D override exists
# for it: under managed, the ordinary single-machine case (the "default" in
# the old four-strategy model, and every discovered fact's straight-through
# strategy since nothing is ever shipped there), it is the discovered
# absolute binary, found once at configure; under full and
# full-permissive-only, which exist to be relocated onto another machine,
# baking in this machine's nvc++ path would be wrong, so the driver just
# invokes "nvc++" and lets PATH answer wherever it ends up driving from.
if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "managed" AND NOT "${ACPP_DISCOVERED_NVHPC_NVCXX}" STREQUAL "")
  set(ACPP_NVCXX "${ACPP_DISCOVERED_NVHPC_NVCXX}")
else()
  set(ACPP_NVCXX "nvc++")
endif()

# No rpath here, and no -Mnorpath either: the CLI driver never adds
# rpaths by itself (doc/design-walkthrough-2026-09-25.md, "Driving") - an
# app builder driving the nvcxx flow by hand owns its own link, same as
# nvc++'s own default behaviour, so nothing here interferes with it
# either. A CMake app gets its rpath from add_sycl_to_target instead
# (Commit 6, ACPP_APP_INSTALL_RPATH), which already covers the nvhpc rt
# subdir under full - see acpp_app_install_rpath's own NVHPC:RT entry.
if(NOT DEFINED ACPP_NVCXX_LINK_LINE)
  set(ACPP_NVCXX_LINK_LINE "")
endif()
