# Discovery check for the OpenCL backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-ocl.cmake
#
# find_library runs in script mode, so this harness exercises the real
# discovery on the current machine.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/ocl.cmake)

if(NOT ACPP_DISCOVERED_OCL_FOUND)
  message(STATUS "SKIP: no OpenCL ICD loader found (libOpenCL.so)")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the prefix root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_OCL_LIBDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_OCL_LOADER}")
  message(FATAL_ERROR "loader not found at ${ACPP_DISCOVERED_OCL_LOADER}")
endif()

message(STATUS
  "discovery/ocl.cmake: loader at ${ACPP_DISCOVERED_OCL_LOADER}, "
  "prefix ${ACPP_DISCOVERED_OCL_PREFIX}, "
  "libdir ${ACPP_DISCOVERED_OCL_LIBDIR}")
