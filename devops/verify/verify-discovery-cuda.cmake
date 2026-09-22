# Discovery check for the CUDA backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-cuda.cmake
#
# find_package(CUDAToolkit) uses add_library internally, which is not
# available in script mode. This harness therefore only runs when cmake is
# invoked with a project context (the staging configure). In script mode it
# SKIPs unconditionally.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(CMAKE_SCRIPT_MODE_FILE)
  message(STATUS "SKIP: find_package(CUDAToolkit) requires project mode")
  return()
endif()

include(${ACPP_REPO_ROOT}/cmake/discovery/cuda.cmake)

if(NOT ACPP_DISCOVERED_CUDA_FOUND)
  message(STATUS "SKIP: no CUDA toolkit found (set CUDAToolkit_ROOT to run this check)")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the toolkit root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_CUDA_LIBDIR)
expect_no_dotdot(ACPP_DISCOVERED_CUDA_INCDIR)
expect_no_dotdot(ACPP_DISCOVERED_CUDA_BINDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}/libdevice.10.bc")
  message(FATAL_ERROR "libdevice.10.bc not found at ${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}")
endif()

message(STATUS "discovery/cuda.cmake: toolkit at ${ACPP_DISCOVERED_CUDA_PREFIX}, layout verified")
