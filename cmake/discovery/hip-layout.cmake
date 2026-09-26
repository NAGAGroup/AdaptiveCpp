# The layout probes cmake/discovery/hip.cmake uses, split out into plain
# functions so a cmake -P harness (devops/verify/verify-hip-layouts.cmake)
# can exercise them directly, against a fake directory tree, without
# find_package(hip) - which creates imported targets and so is unavailable
# in script mode.

include_guard(GLOBAL)

# acpp_hip_probe_bitcode(<out-var> <prefix>)
#
# Finds the directory holding the device bitcode (ockl.bc and friends).
# Upstream's -DROCM_DEVICE_LIBS_PATH is honoured first, if set and it
# actually holds ockl.bc. Otherwise, in order:
#   (1) <prefix>/lib/llvm/amdgcn/bitcode      - TheRock
#   (2) <prefix>/amdgcn/bitcode               - classic ROCm 6.x and
#                                                earlier; also the Windows
#                                                HIP SDK
#   (3) <prefix>/lib/llvm/lib/clang/*/lib/amdgcn/bitcode, highest clang
#       version first - ROCm 7.2+, which moved the device bitcode into the
#       clang resource directory
# "${out_var}" is set to the first directory found to actually contain
# ockl.bc, or "" if none did. "${out_var}_TRIED" is always set, to the
# list of locations tried, for the caller's error message.
function(acpp_hip_probe_bitcode out_var prefix)
  set(_acpp_hlb_tried "")

  if(DEFINED ROCM_DEVICE_LIBS_PATH AND NOT "${ROCM_DEVICE_LIBS_PATH}" STREQUAL "")
    list(APPEND _acpp_hlb_tried "${ROCM_DEVICE_LIBS_PATH} (-DROCM_DEVICE_LIBS_PATH)")
    if(EXISTS "${ROCM_DEVICE_LIBS_PATH}/ockl.bc")
      set(${out_var} "${ROCM_DEVICE_LIBS_PATH}" PARENT_SCOPE)
      set(${out_var}_TRIED "${_acpp_hlb_tried}" PARENT_SCOPE)
      return()
    endif()
  endif()

  # (1) TheRock.
  set(_acpp_hlb_therock "${prefix}/lib/llvm/amdgcn/bitcode")
  list(APPEND _acpp_hlb_tried "${_acpp_hlb_therock}")
  if(EXISTS "${_acpp_hlb_therock}/ockl.bc")
    set(${out_var} "${_acpp_hlb_therock}" PARENT_SCOPE)
    set(${out_var}_TRIED "${_acpp_hlb_tried}" PARENT_SCOPE)
    return()
  endif()

  # (2) Classic ROCm (also the Windows HIP SDK).
  set(_acpp_hlb_classic "${prefix}/amdgcn/bitcode")
  list(APPEND _acpp_hlb_tried "${_acpp_hlb_classic}")
  if(EXISTS "${_acpp_hlb_classic}/ockl.bc")
    set(${out_var} "${_acpp_hlb_classic}" PARENT_SCOPE)
    set(${out_var}_TRIED "${_acpp_hlb_tried}" PARENT_SCOPE)
    return()
  endif()

  # (3) ROCm 7.2+: the clang resource directory. Highest clang version
  # first - a distribution carrying more than one only ever intends the
  # newest to be current.
  file(GLOB _acpp_hlb_resource_dirs LIST_DIRECTORIES true
    "${prefix}/lib/llvm/lib/clang/*/lib/amdgcn/bitcode")
  if(_acpp_hlb_resource_dirs)
    list(SORT _acpp_hlb_resource_dirs COMPARE NATURAL ORDER DESCENDING)
    foreach(_acpp_hlb_dir IN LISTS _acpp_hlb_resource_dirs)
      list(APPEND _acpp_hlb_tried "${_acpp_hlb_dir}")
      if(EXISTS "${_acpp_hlb_dir}/ockl.bc")
        set(${out_var} "${_acpp_hlb_dir}" PARENT_SCOPE)
        set(${out_var}_TRIED "${_acpp_hlb_tried}" PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endif()

  set(${out_var} "" PARENT_SCOPE)
  set(${out_var}_TRIED "${_acpp_hlb_tried}" PARENT_SCOPE)
endfunction()

# acpp_hip_probe_sysdeps(<out-var> <libdir>)
#
# TheRock ships rocm_sysdeps, the tree libhsa-runtime64/libamdhip64 DT_NEED
# through their own $ORIGIN/rocm_sysdeps/lib RUNPATH; classic ROCm does
# not. "${out_var}" is "<libdir>/rocm_sysdeps/lib" if that directory
# exists, else "".
function(acpp_hip_probe_sysdeps out_var libdir)
  set(_acpp_hls_dir "${libdir}/rocm_sysdeps/lib")
  if(IS_DIRECTORY "${_acpp_hls_dir}")
    set(${out_var} "${_acpp_hls_dir}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

# _acpp_hip_probe_one_windows_dll(<files> <pattern> <out-var>) - internal.
#
# The last (list(SORT) COMPARE NATURAL, ascending) of the entries in
# <files> whose lower-cased name matches <pattern>, with its ".dll" (or
# ".DLL", ...) suffix stripped - the newest, when an old unversioned name
# and a new versioned one both match. "" if nothing matched. Matching is
# case-insensitive; the result keeps the file's actual case.
function(_acpp_hip_probe_one_windows_dll files pattern out_var)
  set(_acpp_hlwd_matches "")
  foreach(_acpp_hlwd_f IN LISTS files)
    get_filename_component(_acpp_hlwd_name "${_acpp_hlwd_f}" NAME)
    string(TOLOWER "${_acpp_hlwd_name}" _acpp_hlwd_lower)
    if(_acpp_hlwd_lower MATCHES "${pattern}")
      list(APPEND _acpp_hlwd_matches "${_acpp_hlwd_name}")
    endif()
  endforeach()
  if(_acpp_hlwd_matches)
    list(SORT _acpp_hlwd_matches COMPARE NATURAL)
    list(GET _acpp_hlwd_matches -1 _acpp_hlwd_last)
    get_filename_component(_acpp_hlwd_stem "${_acpp_hlwd_last}" NAME_WE)
    set(${out_var} "${_acpp_hlwd_stem}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

# acpp_hip_probe_windows_dlls(<bindir>)
#
# AMD's HIP SDK versions its Windows DLL names (amdhip64_6.dll/
# amdhip64_7.dll, amd_comgr_2.dll/amd_comgr_3.dll, hiprtcXXYY.dll where
# XXYY is the ROCm version) rather than shipping one fixed name across
# releases, so discovery reports what is actually in <bindir> instead of
# assuming a name. Sets these four in PARENT_SCOPE, each the matching
# DLL's file name without ".dll", or "" if none matched:
#   ACPP_DISCOVERED_HIP_AMDHIP_DLL           - ^amdhip64(_[0-9]+)?\.dll$
#   ACPP_DISCOVERED_HIP_COMGR_DLL            - ^amd_comgr(_[0-9]+)?\.dll$
#   ACPP_DISCOVERED_HIP_HIPRTC_DLL           - ^hiprtc[0-9]+\.dll$
#   ACPP_DISCOVERED_HIP_HIPRTC_BUILTINS_DLL  - ^hiprtc-builtins[0-9]+\.dll$
function(acpp_hip_probe_windows_dlls bindir)
  # "*" rather than "*.dll": file(GLOB) matches the filesystem's own case
  # sensitivity, which would silently miss a ".DLL" (or any other case
  # variant of the extension) on a case-sensitive filesystem - the probe
  # functions below already match the whole (lower-cased) name, extension
  # included, so nothing is lost by not filtering here.
  file(GLOB _acpp_hlwd_files RELATIVE "${bindir}" "${bindir}/*")

  _acpp_hip_probe_one_windows_dll("${_acpp_hlwd_files}" "^amdhip64(_[0-9]+)?\\.dll$" _acpp_hlwd_amdhip)
  _acpp_hip_probe_one_windows_dll("${_acpp_hlwd_files}" "^amd_comgr(_[0-9]+)?\\.dll$" _acpp_hlwd_comgr)
  _acpp_hip_probe_one_windows_dll("${_acpp_hlwd_files}" "^hiprtc[0-9]+\\.dll$" _acpp_hlwd_hiprtc)
  _acpp_hip_probe_one_windows_dll("${_acpp_hlwd_files}" "^hiprtc-builtins[0-9]+\\.dll$" _acpp_hlwd_hiprtc_builtins)

  set(ACPP_DISCOVERED_HIP_AMDHIP_DLL "${_acpp_hlwd_amdhip}" PARENT_SCOPE)
  set(ACPP_DISCOVERED_HIP_COMGR_DLL "${_acpp_hlwd_comgr}" PARENT_SCOPE)
  set(ACPP_DISCOVERED_HIP_HIPRTC_DLL "${_acpp_hlwd_hiprtc}" PARENT_SCOPE)
  set(ACPP_DISCOVERED_HIP_HIPRTC_BUILTINS_DLL "${_acpp_hlwd_hiprtc_builtins}" PARENT_SCOPE)
endfunction()
