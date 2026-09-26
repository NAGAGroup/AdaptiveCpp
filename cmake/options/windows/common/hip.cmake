# HIP options - windows, x86_64 only (AMD's HIP SDK ships for x86_64 only,
# no aarch64 unit exists).
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
acpp_declare_vendor_subdir_fact(HIP BIN ACPP_DISCOVERED_HIP_BINDIR "${ACPP_DISCOVERED_HIP_BINDIR}")
acpp_declare_vendor_subdir_fact(HIP BITCODE ACPP_DISCOVERED_HIP_BITCODE_DIR "${ACPP_DISCOVERED_HIP_BITCODE_DIR}")

# The application's own view of each (D7): the manifest's app-config
# section embeds these via @VAR@; Piece 3's concern to wire in. BIN doubles
# as the DLL directory AddDllDirectory is fed, which is why it is declared
# here rather than skipped the way it would be if only the import library
# at RT mattered.
acpp_declare_vendor_app_dir(HIP hip RT)
acpp_declare_vendor_app_dir(HIP hip INCLUDE)
acpp_declare_vendor_app_dir(HIP hip BIN)
acpp_declare_vendor_app_dir(HIP hip BITCODE)

# ---------------------------------------------------------------------------
# The SDK's own versioned DLL names - discovery's plain facts, not subdir
# facts (they are file names, not directories).
# ---------------------------------------------------------------------------

set(ACPP_HIP_AMDHIP_DLL "${ACPP_DISCOVERED_HIP_AMDHIP_DLL}")
set(ACPP_HIP_COMGR_DLL "${ACPP_DISCOVERED_HIP_COMGR_DLL}")
set(ACPP_HIP_HIPRTC_DLL "${ACPP_DISCOVERED_HIP_HIPRTC_DLL}")
set(ACPP_HIP_HIPRTC_BUILTINS_DLL "${ACPP_DISCOVERED_HIP_HIPRTC_BUILTINS_DLL}")

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------
#
# Windows has no RUNPATH, so no -Wl,-rpath; hip-rt-subdir here names
# wherever the import library (amdhip64.lib) landed.

if(NOT DEFINED ACPP_HIP_LINK_LINE)
  set(ACPP_HIP_LINK_LINE "-L{{ hip-install-root }}/{{ hip-rt-subdir }} -lamdhip64")
endif()

if(NOT DEFINED ACPP_HIP_CXX_FLAGS)
  set(ACPP_HIP_CXX_FLAGS "-isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-install-root }}/{{ hip-include-subdir }} --rocm-device-lib-path={{ hip-install-root }}/{{ hip-bitcode-subdir }} --rocm-path={{ hip-install-root }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")
endif()
