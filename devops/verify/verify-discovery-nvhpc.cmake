# Discovery check for the HPC SDK, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-nvhpc.cmake
#
# find_program and execute_process are script-mode safe, so this harness
# runs directly. SKIPs when nvc++ is not found.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/nvhpc.cmake)

if(NOT ACPP_DISCOVERED_NVHPC_FOUND)
  message(STATUS "SKIP: nvc++ not found on PATH")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the SDK root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_NVHPC_LIBDIR)

if(NOT IS_DIRECTORY "${ACPP_DISCOVERED_NVHPC_PREFIX}/${ACPP_DISCOVERED_NVHPC_LIBDIR}")
  message(FATAL_ERROR
    "redistributable runtime not found at "
    "${ACPP_DISCOVERED_NVHPC_PREFIX}/${ACPP_DISCOVERED_NVHPC_LIBDIR}")
endif()

message(STATUS
  "discovery/nvhpc.cmake: SDK at ${ACPP_DISCOVERED_NVHPC_PREFIX}, "
  "nvc++ ${ACPP_DISCOVERED_NVHPC_VERSION_MAJOR}.${ACPP_DISCOVERED_NVHPC_VERSION_MINOR}")
