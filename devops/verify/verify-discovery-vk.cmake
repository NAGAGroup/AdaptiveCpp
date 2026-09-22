# Discovery check for the Vulkan backend, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-vk.cmake
#
# find_library and find_path run in script mode, so this harness exercises
# the real discovery on the current machine.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

include(${ACPP_REPO_ROOT}/cmake/discovery/vk.cmake)

if(NOT ACPP_DISCOVERED_VK_FOUND)
  message(STATUS "SKIP: Vulkan loader, headers or SPIRV-Tools not found")
  return()
endif()

function(expect_no_dotdot name)
  if("${${name}}" MATCHES "^\\.\\.")
    message(FATAL_ERROR "${name} = '${${name}}' escapes the prefix root")
  endif()
endfunction()

expect_no_dotdot(ACPP_DISCOVERED_VK_LIBDIR)

if(NOT EXISTS "${ACPP_DISCOVERED_VK_LOADER}")
  message(FATAL_ERROR "loader not found at ${ACPP_DISCOVERED_VK_LOADER}")
endif()

if(NOT IS_DIRECTORY "${ACPP_DISCOVERED_VK_INCLUDE_DIR}")
  message(FATAL_ERROR "include dir not found at ${ACPP_DISCOVERED_VK_INCLUDE_DIR}")
endif()

message(STATUS
  "discovery/vk.cmake: loader at ${ACPP_DISCOVERED_VK_LOADER}, "
  "prefix ${ACPP_DISCOVERED_VK_PREFIX}, "
  "libdir ${ACPP_DISCOVERED_VK_LIBDIR}")
