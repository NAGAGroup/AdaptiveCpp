# Discovery check for the HIP backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-hip.cmake
#
# find_package(hip) creates imported targets, which is not available in
# script mode. This harness SKIPs unconditionally in script mode.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(CMAKE_SCRIPT_MODE_FILE)
  message(STATUS "SKIP: find_package(hip) requires project mode")
  return()
endif()

include(${ACPP_REPO_ROOT}/cmake/discovery/hip.cmake)

if(NOT ACPP_DISCOVERED_HIP_FOUND)
  message(STATUS "SKIP: no TheRock ROCm distribution found (set ROCM_PATH or hip_ROOT)")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the distribution root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_HIP_LIBDIR)
expect_no_dotdot(ACPP_DISCOVERED_HIP_INCDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_BITCODE_DIR}/ockl.bc")
  message(FATAL_ERROR "ockl.bc not found at ${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_BITCODE_DIR}")
endif()

message(STATUS
  "discovery/hip.cmake: distribution at ${ACPP_DISCOVERED_HIP_PREFIX}, "
  "HIP ${ACPP_DISCOVERED_HIP_VERSION_MAJOR}.${ACPP_DISCOVERED_HIP_VERSION_MINOR}, "
  "hipRTC ${ACPP_DISCOVERED_HIP_HIPRTC}")
