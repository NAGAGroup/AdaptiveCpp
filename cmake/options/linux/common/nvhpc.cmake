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

acpp_declare_vendor_subdir(NVHPC nvhpc)
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
# for it (D1): under `default` it is the discovered absolute binary, found
# once at configure; otherwise the driver just invokes "nvc++" and lets
# PATH answer, on whichever machine drives the build.
if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND NOT "${ACPP_DISCOVERED_NVHPC_NVCXX}" STREQUAL "")
  set(ACPP_NVCXX "${ACPP_DISCOVERED_NVHPC_NVCXX}")
else()
  set(ACPP_NVCXX "nvc++")
endif()

# -Mnorpath suppresses the RPATH nvc++ would stamp into the application,
# which names the SDK on the building machine; ours names the unit, which
# travels. nvc++ links cudart from the CUDA bundled inside the SDK, but at
# run time the application resolves the soname through our RUNPATH to the
# toolkit unit's copy, the one rt-backend-cuda was built against; the
# toolkit unit is always present for this flow because the backend is built
# against it, and when only the SDK is installed the toolkit unit simply is
# the SDK's bundled CUDA, pointed at through CUDAToolkit_ROOT.
if(NOT DEFINED ACPP_NVCXX_LINK_LINE)
  set(ACPP_NVCXX_LINK_LINE "-Mnorpath -Wl,-rpath={{ nvhpc-install-root }}/{{ nvhpc-rt-subdir }} -Wl,-rpath={{ cuda-install-root }}/{{ cuda-rt-subdir }}")
endif()
