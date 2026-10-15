# HPC SDK runtime options - linux, every architecture.
#
# Include after core.cmake, only when the nvcxx compilation flow is enabled;
# the helpers live in core. The HPC SDK is a separate product from the CUDA
# toolkit with its own terms and lifecycle, so its redistributable runtime is
# its own vendor unit, declared unbundleable: it is never installed with the
# toolchain - see "Vendor units" in the common core file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# The install subdir knob and the root it derives
# ---------------------------------------------------------------------------
#
# ACPP_DISCOVERED_NVHPC_PREFIX is already the SDK's REDIST root
# (<sdk-root>/REDIST), not the SDK root itself: the redistributable runtime
# is the vendor unit here, not the compiler.

acpp_declare_unbundleable_vendor(NVHPC nvhpc)
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
# tree (NVHPC is never bundled). No -D override exists for it: when
# discovery found nvc++ it is the discovered absolute binary, found once at
# configure; otherwise the driver just invokes "nvc++" and lets PATH answer.
if(NOT "${ACPP_DISCOVERED_NVHPC_NVCXX}" STREQUAL "")
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
# subdir - see acpp_app_install_rpath's own NVHPC:RT entry.
if(NOT DEFINED ACPP_NVCXX_LINK_LINE)
  set(ACPP_NVCXX_LINK_LINE "")
endif()
