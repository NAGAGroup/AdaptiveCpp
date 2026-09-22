# Discovery check for the Level Zero backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-ze.cmake
#
# find_library and find_path run in script mode, so this harness exercises
# the real discovery on the current machine.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/ze.cmake)

if(NOT ACPP_ZE_LOADER_LIBRARY OR "${ACPP_ZE_LOADER_LIBRARY}" MATCHES "-NOTFOUND$")
  message(STATUS "SKIP: no Level Zero loader found (libze_loader.so)")
  return()
endif()

if(NOT ACPP_ZE_INCLUDE_DIR OR "${ACPP_ZE_INCLUDE_DIR}" MATCHES "-NOTFOUND$")
  message(STATUS "SKIP: loader found but level_zero/ze_api.h is not")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the prefix root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_ZE_LIBDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_ZE_LOADER}")
  message(FATAL_ERROR "loader not found at ${ACPP_DISCOVERED_ZE_LOADER}")
endif()

if(NOT IS_DIRECTORY "${ACPP_DISCOVERED_ZE_INCLUDE_DIR}")
  message(FATAL_ERROR "include dir not found at ${ACPP_DISCOVERED_ZE_INCLUDE_DIR}")
endif()

message(STATUS
  "discovery/ze.cmake: loader at ${ACPP_DISCOVERED_ZE_LOADER}, "
  "prefix ${ACPP_DISCOVERED_ZE_PREFIX}, "
  "libdir ${ACPP_DISCOVERED_ZE_LIBDIR}, "
  "include ${ACPP_DISCOVERED_ZE_INCLUDE_DIR}")
