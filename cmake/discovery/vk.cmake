# Vulkan backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_VK_*. Not found is the normalized empty string.
# The unit is the Vulkan loader and nothing else; the Vulkan headers and
# the static SPIRV-Tools archive are discovery requirements (the runtime
# cannot be built without them) but never manifest rows.
#
# find_package(Vulkan) is not used because it creates imported targets and
# cannot run under cmake -P; its components mix build-only libraries with
# the loader.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

find_library(ACPP_VK_LOADER_LIBRARY NAMES vulkan vulkan-1)
find_path(ACPP_VK_INCLUDE_DIR NAMES vulkan/vulkan.h)
find_library(ACPP_VK_SPIRV_TOOLS_LIBRARY NAMES SPIRV-Tools)

if(ACPP_VK_LOADER_LIBRARY AND NOT "${ACPP_VK_LOADER_LIBRARY}" MATCHES "-NOTFOUND$"
    AND ACPP_VK_INCLUDE_DIR AND NOT "${ACPP_VK_INCLUDE_DIR}" MATCHES "-NOTFOUND$"
    AND ACPP_VK_SPIRV_TOOLS_LIBRARY AND NOT "${ACPP_VK_SPIRV_TOOLS_LIBRARY}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_VK_FOUND ON)

  get_filename_component(_acpp_vk_real "${ACPP_VK_LOADER_LIBRARY}" REALPATH)
  set(ACPP_DISCOVERED_VK_LOADER "${_acpp_vk_real}")
  get_filename_component(_acpp_vk_libdir "${_acpp_vk_real}" DIRECTORY)

  acpp_common_ancestor(ACPP_DISCOVERED_VK_PREFIX "${_acpp_vk_libdir}")
  file(RELATIVE_PATH ACPP_DISCOVERED_VK_LIBDIR
    "${ACPP_DISCOVERED_VK_PREFIX}" "${_acpp_vk_libdir}")

  # Build-only: consumed by the runtime target's include directories and
  # link line, never written to the configuration.
  set(ACPP_DISCOVERED_VK_INCLUDE_DIR "${ACPP_VK_INCLUDE_DIR}")
  set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "${ACPP_VK_SPIRV_TOOLS_LIBRARY}")

  # On Windows find_library answers with the SDK's import library, and that
  # is all the SDK carries; the loader vulkan-1.dll lives in System32,
  # installed by graphics drivers or the Vulkan runtime installer, and the
  # loader's maintainers advise against bundling it. The Vulkan unit
  # therefore deploys nothing on Windows, exports no DLL directory, and the
  # runtime reaches the machine's loader as it would a driver.
else()
  set(ACPP_DISCOVERED_VK_FOUND OFF)
  set(ACPP_DISCOVERED_VK_LOADER "")
  set(ACPP_DISCOVERED_VK_PREFIX "")
  set(ACPP_DISCOVERED_VK_LIBDIR "")
  set(ACPP_DISCOVERED_VK_INCLUDE_DIR "")
  set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "")
endif()
