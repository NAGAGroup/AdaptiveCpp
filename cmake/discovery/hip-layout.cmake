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
