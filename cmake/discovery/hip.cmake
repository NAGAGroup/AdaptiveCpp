# HIP backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_HIP_*. Not found is the normalized empty string.
# Accepts TheRock, classic ROCm (bitcode under amdgcn/bitcode) and ROCm
# 7.2+ (bitcode in the clang resource directory); upstream's
# -DROCM_DEVICE_LIBS_PATH overrides the bitcode probe.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/hip-layout.cmake)

# hip-config.cmake otherwise runs hipconfig --platform, which answers nvidia
# on a machine with CUDA and no AMD runtime, and hip::host then carries no
# library. We build against an AMD distribution; there is nothing to detect.
if(NOT DEFINED HIP_PLATFORM)
  set(HIP_PLATFORM "amd")
endif()

# Let upstream's ROCM_PATH spelling work.
if(DEFINED ROCM_PATH AND NOT DEFINED hip_ROOT)
  set(hip_ROOT "${ROCM_PATH}")
endif()

find_package(hip CONFIG QUIET)

if(hip_FOUND)
  set(ACPP_DISCOVERED_HIP_FOUND ON)

  # Device bitcode: probed across every layout this discovery accepts.
  # HIP_PACKAGE_PREFIX_DIR is a search hint here, not an asserted prefix -
  # the common ancestor below is what the prefix actually becomes.
  acpp_hip_probe_bitcode(_acpp_hip_bitcode_dir "${HIP_PACKAGE_PREFIX_DIR}")
  if("${_acpp_hip_bitcode_dir}" STREQUAL "")
    list(JOIN _acpp_hip_bitcode_dir_TRIED ", " _acpp_hip_bitcode_tried_joined)
    message(FATAL_ERROR
      "HIP was found at ${HIP_PACKAGE_PREFIX_DIR} but no device bitcode "
      "(ockl.bc) was found. Tried: ${_acpp_hip_bitcode_tried_joined}. Point "
      "-DROCM_DEVICE_LIBS_PATH at the directory holding ockl.bc.")
  endif()

  # rocm_sysdeps: only TheRock ships it.
  acpp_hip_probe_sysdeps(_acpp_hip_sysdeps_dir "${hip_LIB_INSTALL_DIR}")

  # The prefix is derived, not asserted: the common ancestor of every
  # piece discovery actually found.
  acpp_common_ancestor(ACPP_DISCOVERED_HIP_PREFIX
    "${hip_LIB_INSTALL_DIR}"
    "${hip_INCLUDE_DIR}"
    "${_acpp_hip_bitcode_dir}")

  file(RELATIVE_PATH ACPP_DISCOVERED_HIP_LIBDIR
    "${ACPP_DISCOVERED_HIP_PREFIX}" "${hip_LIB_INSTALL_DIR}")
  file(RELATIVE_PATH ACPP_DISCOVERED_HIP_INCDIR
    "${ACPP_DISCOVERED_HIP_PREFIX}" "${hip_INCLUDE_DIR}")
  file(RELATIVE_PATH ACPP_DISCOVERED_HIP_BITCODE_DIR
    "${ACPP_DISCOVERED_HIP_PREFIX}" "${_acpp_hip_bitcode_dir}")
  if(NOT "${_acpp_hip_sysdeps_dir}" STREQUAL "")
    file(RELATIVE_PATH ACPP_DISCOVERED_HIP_SYSDEPS_DIR
      "${ACPP_DISCOVERED_HIP_PREFIX}" "${_acpp_hip_sysdeps_dir}")
  else()
    set(ACPP_DISCOVERED_HIP_SYSDEPS_DIR "")
  endif()

  # Version.
  if(DEFINED hip_VERSION_MAJOR)
    set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "${hip_VERSION_MAJOR}")
    set(ACPP_DISCOVERED_HIP_VERSION_MINOR "${hip_VERSION_MINOR}")
  elseif("${hip_VERSION}" MATCHES "^([0-9]+)\\.([0-9]+)")
    set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(ACPP_DISCOVERED_HIP_VERSION_MINOR "${CMAKE_MATCH_2}")
  else()
    set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "")
    set(ACPP_DISCOVERED_HIP_VERSION_MINOR "")
  endif()

  # hipRTC presence. A classic install may ship only the soname link
  # (libhiprtc.so.N), not the unversioned one.
  file(GLOB _acpp_hip_hiprtc "${hip_LIB_INSTALL_DIR}/libhiprtc.so*")
  if(_acpp_hip_hiprtc)
    set(ACPP_DISCOVERED_HIP_HIPRTC ON)
  else()
    set(ACPP_DISCOVERED_HIP_HIPRTC OFF)
  endif()
else()
  set(ACPP_DISCOVERED_HIP_FOUND OFF)
  set(ACPP_DISCOVERED_HIP_PREFIX "")
  set(ACPP_DISCOVERED_HIP_LIBDIR "")
  set(ACPP_DISCOVERED_HIP_INCDIR "")
  set(ACPP_DISCOVERED_HIP_BITCODE_DIR "")
  set(ACPP_DISCOVERED_HIP_SYSDEPS_DIR "")
  set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "")
  set(ACPP_DISCOVERED_HIP_VERSION_MINOR "")
  set(ACPP_DISCOVERED_HIP_HIPRTC OFF)
endif()
