# Discovery check for clspv, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-clspv.cmake
#
# find_program runs in script mode, so this harness exercises the real
# discovery on the current machine.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/clspv.cmake)

if(NOT ACPP_DISCOVERED_CLSPV_FOUND)
  if("${ACPP_DISCOVERED_CLSPV_EXECUTABLE}" STREQUAL "")
    message(STATUS "SKIP: clspv not found on PATH")
  else()
    message(FATAL_ERROR "FOUND is OFF but EXECUTABLE is not empty")
  endif()
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the prefix root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_CLSPV_BINDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_CLSPV_EXECUTABLE}")
  message(FATAL_ERROR "clspv not found at ${ACPP_DISCOVERED_CLSPV_EXECUTABLE}")
endif()

message(STATUS
  "discovery/clspv.cmake: clspv at ${ACPP_DISCOVERED_CLSPV_EXECUTABLE}, "
  "prefix ${ACPP_DISCOVERED_CLSPV_PREFIX}, "
  "bindir ${ACPP_DISCOVERED_CLSPV_BINDIR}")
