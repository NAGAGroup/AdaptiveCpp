# HIP options - linux, every architecture.
#
# Include after core.cmake, only when the HIP backend is enabled; the
# helpers and the strategy control live in core. Two knobs (ACPP_HIP_SUBDIR
# plus whatever hip_ROOT/ROCM_PATH steer discovery), everything else
# derived - see "Vendor units" in the common core file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# The install subdir knob and the root it derives
# ---------------------------------------------------------------------------

acpp_declare_vendor(HIP hip permissive)
acpp_declare_vendor_root(HIP hip ACPP_DISCOVERED_HIP_PREFIX "${ACPP_DISCOVERED_HIP_PREFIX}")

# ---------------------------------------------------------------------------
# Subdirs inside the vendor unit - discovery's own relative facts
# ---------------------------------------------------------------------------

acpp_declare_vendor_subdir_fact(HIP RT ACPP_DISCOVERED_HIP_LIBDIR "${ACPP_DISCOVERED_HIP_LIBDIR}")
acpp_declare_vendor_subdir_fact(HIP INCLUDE ACPP_DISCOVERED_HIP_INCDIR "${ACPP_DISCOVERED_HIP_INCDIR}")
acpp_declare_vendor_subdir_fact(HIP BITCODE ACPP_DISCOVERED_HIP_BITCODE_DIR "${ACPP_DISCOVERED_HIP_BITCODE_DIR}")

# TheRock's libhsa-runtime64/libamdhip64 DT_NEED librocm_sysdeps_* through
# their own $ORIGIN/rocm_sysdeps/lib RUNPATH; discovery reports where that
# tree is, and empty where the distribution has none (classic ROCm).
acpp_declare_vendor_subdir_fact(HIP SYSDEPS ACPP_DISCOVERED_HIP_SYSDEPS_DIR "${ACPP_DISCOVERED_HIP_SYSDEPS_DIR}")

# The application's own view of each (D7): the manifest's app-config
# section embeds these via @VAR@; Piece 3's concern to wire in.
acpp_declare_vendor_app_dir(HIP hip RT)
acpp_declare_vendor_app_dir(HIP hip INCLUDE)
acpp_declare_vendor_app_dir(HIP hip BITCODE)
acpp_declare_vendor_app_dir(HIP hip SYSDEPS)

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------
#
# No -Wl,-rpath here: the CLI driver never adds rpaths by itself (doc/
# design-walkthrough-2026-09-25.md, "Driving") - an app builder driving
# the multipass flow by hand owns its own link, and a CMake app gets its
# rpath from add_sycl_to_target (Commit 6, ACPP_APP_INSTALL_RPATH).

if(NOT DEFINED ACPP_HIP_LINK_LINE)
  set(ACPP_HIP_LINK_LINE "-L{{ hip-install-root }}/{{ hip-rt-subdir }} -lamdhip64")
endif()

if(NOT DEFINED ACPP_HIP_CXX_FLAGS)
  set(ACPP_HIP_CXX_FLAGS "-isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-install-root }}/{{ hip-include-subdir }} --rocm-device-lib-path={{ hip-install-root }}/{{ hip-bitcode-subdir }} --rocm-path={{ hip-install-root }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")
endif()
