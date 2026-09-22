# HIP backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_HIP_*. Not found is the normalized empty string.
# Only TheRock's ROCm distribution is supported; classic /opt/rocm layouts
# fail at configure.

include_guard(GLOBAL)

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
  set(ACPP_DISCOVERED_HIP_PREFIX "${HIP_PACKAGE_PREFIX_DIR}")

  # Relative facts: the vendor unit deploys in its own relative layout.
  foreach(_acpp_hip_pair
      "ACPP_DISCOVERED_HIP_LIBDIR;${hip_LIB_INSTALL_DIR}"
      "ACPP_DISCOVERED_HIP_INCDIR;${hip_INCLUDE_DIR}")
    list(GET _acpp_hip_pair 0 _acpp_hip_var)
    list(GET _acpp_hip_pair 1 _acpp_hip_dir)
    file(RELATIVE_PATH _acpp_hip_rel "${HIP_PACKAGE_PREFIX_DIR}" "${_acpp_hip_dir}")
    if("${_acpp_hip_rel}" STREQUAL "" OR "${_acpp_hip_rel}" MATCHES "^\\.\\.")
      message(FATAL_ERROR
        "${_acpp_hip_var}: '${_acpp_hip_dir}' is not inside "
        "'${HIP_PACKAGE_PREFIX_DIR}'. The vendor unit deploys in the "
        "distribution's own relative layout; a directory outside the root "
        "has no place in it.")
    endif()
    set(${_acpp_hip_var} "${_acpp_hip_rel}")
  endforeach()

  # Device bitcode: TheRock's layout places it under lib/llvm/amdgcn/bitcode.
  set(ACPP_DISCOVERED_HIP_BITCODE_DIR "lib/llvm/amdgcn/bitcode")
  if(NOT EXISTS "${HIP_PACKAGE_PREFIX_DIR}/${ACPP_DISCOVERED_HIP_BITCODE_DIR}/ockl.bc")
    message(FATAL_ERROR
      "This is not a TheRock distribution: "
      "${HIP_PACKAGE_PREFIX_DIR}/${ACPP_DISCOVERED_HIP_BITCODE_DIR}/ockl.bc "
      "does not exist. Classic ROCm layouts are not supported.")
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

  # hipRTC presence.
  if(EXISTS "${HIP_PACKAGE_PREFIX_DIR}/${ACPP_DISCOVERED_HIP_LIBDIR}/libhiprtc.so")
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
