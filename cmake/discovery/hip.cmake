# HIP backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_HIP_*. Not found is the normalized empty string.
# Only TheRock's ROCm distribution is supported; classic /opt/rocm layouts
# fail at configure.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

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

  # Device bitcode: TheRock's layout places it under lib/llvm/amdgcn/bitcode.
  # HIP_PACKAGE_PREFIX_DIR is a search hint here, not an asserted prefix -
  # the common ancestor below is what the prefix actually becomes.
  set(_acpp_hip_bitcode_dir "${HIP_PACKAGE_PREFIX_DIR}/lib/llvm/amdgcn/bitcode")
  if(NOT EXISTS "${_acpp_hip_bitcode_dir}/ockl.bc")
    message(FATAL_ERROR
      "This is not a TheRock distribution: ${_acpp_hip_bitcode_dir}/ockl.bc "
      "does not exist. Classic ROCm layouts are not supported.")
  endif()

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

  # hipRTC presence.
  if(EXISTS "${hip_LIB_INSTALL_DIR}/libhiprtc.so")
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
  set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "")
  set(ACPP_DISCOVERED_HIP_VERSION_MINOR "")
  set(ACPP_DISCOVERED_HIP_HIPRTC OFF)
endif()
