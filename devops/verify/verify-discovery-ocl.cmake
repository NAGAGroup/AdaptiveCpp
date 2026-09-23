# Discovery check for the OpenCL backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-ocl.cmake
#
# find_package(OpenCL) defines the imported target OpenCL::OpenCL, which
# needs add_library; that is not available in script mode. This harness
# therefore only runs when cmake is invoked with a project context (the
# staging configure). In script mode it SKIPs unconditionally.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(CMAKE_SCRIPT_MODE_FILE)
  message(STATUS "SKIP: find_package(OpenCL) requires project mode")
  return()
endif()

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
