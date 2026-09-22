# Discovery check for the Metal backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-metal.cmake
#
# find_path runs in script mode, so this harness exercises the real
# discovery on the current machine.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/metal.cmake)

if(NOT ACPP_DISCOVERED_METAL_FOUND)
  if("${ACPP_DISCOVERED_METAL_INCLUDE_DIR}" STREQUAL "")
    message(STATUS "SKIP: metal-cpp not found (Metal/Metal.hpp not on the include path)")
  else()
    message(FATAL_ERROR "FOUND is OFF but INCLUDE_DIR is not empty")
  endif()
  return()
endif()

if(NOT IS_DIRECTORY "${ACPP_DISCOVERED_METAL_INCLUDE_DIR}")
  message(FATAL_ERROR "include dir not found at ${ACPP_DISCOVERED_METAL_INCLUDE_DIR}")
endif()

message(STATUS
  "discovery/metal.cmake: metal-cpp at ${ACPP_DISCOVERED_METAL_INCLUDE_DIR}")
