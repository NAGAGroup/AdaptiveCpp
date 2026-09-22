# Level Zero backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_ZE_*. Not found is the normalized empty string.
# The unit is the loader and nothing else; the headers are the machine's,
# build-only, a discovery requirement but not a manifest row because
# nothing user-facing includes them.

include_guard(GLOBAL)

find_library(ACPP_ZE_LOADER_LIBRARY NAMES ze_loader)
find_path(ACPP_ZE_INCLUDE_DIR NAMES level_zero/ze_api.h)

if(ACPP_ZE_LOADER_LIBRARY AND NOT "${ACPP_ZE_LOADER_LIBRARY}" MATCHES "-NOTFOUND$"
    AND ACPP_ZE_INCLUDE_DIR AND NOT "${ACPP_ZE_INCLUDE_DIR}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_ZE_FOUND ON)

  # find_library answers with the dev symlink; the real file is what deploy
  # copies and what SHARED_LIB: resolves to.
  get_filename_component(_acpp_ze_real "${ACPP_ZE_LOADER_LIBRARY}" REALPATH)
  set(ACPP_DISCOVERED_ZE_LOADER "${_acpp_ze_real}")

  get_filename_component(_acpp_ze_libdir "${_acpp_ze_real}" DIRECTORY)
  get_filename_component(ACPP_DISCOVERED_ZE_PREFIX "${_acpp_ze_libdir}" DIRECTORY)

  file(RELATIVE_PATH _acpp_ze_rel "${ACPP_DISCOVERED_ZE_PREFIX}" "${_acpp_ze_libdir}")
  if("${_acpp_ze_rel}" STREQUAL "" OR "${_acpp_ze_rel}" MATCHES "^\\.\\.")
    message(FATAL_ERROR
      "ACPP_DISCOVERED_ZE_LIBDIR: '${_acpp_ze_libdir}' is not inside "
      "'${ACPP_DISCOVERED_ZE_PREFIX}'. The vendor unit deploys in the "
      "distribution's own relative layout; a directory outside the root "
      "has no place in it.")
  endif()
  set(ACPP_DISCOVERED_ZE_LIBDIR "${_acpp_ze_rel}")

  # Build-only: consumed by the runtime target's include directories, never
  # written to the configuration.
  set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "${ACPP_ZE_INCLUDE_DIR}")
else()
  set(ACPP_DISCOVERED_ZE_FOUND OFF)
  set(ACPP_DISCOVERED_ZE_LOADER "")
  set(ACPP_DISCOVERED_ZE_PREFIX "")
  set(ACPP_DISCOVERED_ZE_LIBDIR "")
  set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "")
endif()
