# CUDA options - windows, every architecture.
#
# Include after core.cmake, only when the CUDA backend is enabled; the
# helpers and the strategy control live in core. Two knobs (ACPP_CUDA_SUBDIR
# plus whatever CUDAToolkit_ROOT and friends steer discovery), everything
# else derived - see "Vendor units" in the common core file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# The install subdir knob and the root it derives
# ---------------------------------------------------------------------------

acpp_declare_vendor_subdir(CUDA cuda)
acpp_declare_vendor_root(CUDA cuda ACPP_DISCOVERED_CUDA_PREFIX "${ACPP_DISCOVERED_CUDA_PREFIX}")

# ---------------------------------------------------------------------------
# Subdirs inside the vendor unit - discovery's own relative facts
# ---------------------------------------------------------------------------

acpp_declare_vendor_subdir_fact(CUDA RT ACPP_DISCOVERED_CUDA_LIBDIR "${ACPP_DISCOVERED_CUDA_LIBDIR}")
acpp_declare_vendor_subdir_fact(CUDA INCLUDE ACPP_DISCOVERED_CUDA_INCDIR "${ACPP_DISCOVERED_CUDA_INCDIR}")
acpp_declare_vendor_subdir_fact(CUDA BIN ACPP_DISCOVERED_CUDA_BINDIR "${ACPP_DISCOVERED_CUDA_BINDIR}")
acpp_declare_vendor_subdir_fact(CUDA LIBDEVICE ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}")

# The application's own view of each (D7): the manifest's app-config
# section embeds these via @VAR@; Piece 3's concern to wire in. BIN doubles
# as the DLL directory Windows feeds AddDllDirectory through, which is why
# it is declared here rather than skipped the way it would be if only the
# import library at RT mattered.
acpp_declare_vendor_app_subdir(CUDA cuda RT)
acpp_declare_vendor_app_subdir(CUDA cuda INCLUDE)
acpp_declare_vendor_app_subdir(CUDA cuda BIN)
acpp_declare_vendor_app_subdir(CUDA cuda LIBDEVICE)

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------
#
# Windows has no RUNPATH, so no -Wl,-rpath; cuda-rt-subdir here names
# wherever the import library (cudart.lib) landed.

if(NOT DEFINED ACPP_CUDA_LINK_LINE)
  set(ACPP_CUDA_LINK_LINE "-L{{ cuda-install-root }}/{{ cuda-rt-subdir }} -lcudart")
endif()
if(NOT DEFINED ACPP_CUDA_CXX_FLAGS)
  set(ACPP_CUDA_CXX_FLAGS "-U__FLOAT128__ -U__SIZEOF_FLOAT128__ -isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike")
endif()
