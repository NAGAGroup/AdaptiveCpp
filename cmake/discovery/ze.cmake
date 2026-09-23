# Level Zero backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_ZE_*. Not found is the normalized empty string.
# The unit is the loader and nothing else; the headers are the machine's,
# build-only, a discovery requirement but not a manifest row because
# nothing user-facing includes them.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

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

  # Build-only: consumed by the runtime target's include directories, never
  # written to the configuration.
  set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "${ACPP_ZE_INCLUDE_DIR}")

  # On Windows find_library answers with the import library; the DLL is what
  # deploys and what the runtime must reach through AddDllDirectory. This
  # branch is parse-checked on Linux and exercised on Windows only. The
  # search hint is a guess, not an asserted prefix - the common ancestor
  # below settles it regardless of whether the guess was right.
  if(WIN32)
    get_filename_component(_acpp_ze_hint "${_acpp_ze_libdir}" DIRECTORY)
    find_file(ACPP_ZE_LOADER_DLL NAMES ze_loader.dll
      HINTS "${_acpp_ze_hint}/bin" NO_DEFAULT_PATH)
    if(NOT ACPP_ZE_LOADER_DLL OR "${ACPP_ZE_LOADER_DLL}" MATCHES "-NOTFOUND$")
      message(FATAL_ERROR
        "ze_loader import library found at ${ACPP_ZE_LOADER_LIBRARY} but "
        "ze_loader.dll was not found in ${_acpp_ze_hint}/bin")
    endif()
    get_filename_component(_acpp_ze_dlldir "${ACPP_ZE_LOADER_DLL}" DIRECTORY)

    acpp_common_ancestor(ACPP_DISCOVERED_ZE_PREFIX
      "${_acpp_ze_libdir}" "${_acpp_ze_dlldir}")
    file(RELATIVE_PATH ACPP_DISCOVERED_ZE_BINDIR
      "${ACPP_DISCOVERED_ZE_PREFIX}" "${_acpp_ze_dlldir}")
  else()
    acpp_common_ancestor(ACPP_DISCOVERED_ZE_PREFIX "${_acpp_ze_libdir}")
    set(ACPP_DISCOVERED_ZE_BINDIR "")
  endif()

  file(RELATIVE_PATH ACPP_DISCOVERED_ZE_LIBDIR
    "${ACPP_DISCOVERED_ZE_PREFIX}" "${_acpp_ze_libdir}")
else()
  set(ACPP_DISCOVERED_ZE_FOUND OFF)
  set(ACPP_DISCOVERED_ZE_LOADER "")
  set(ACPP_DISCOVERED_ZE_PREFIX "")
  set(ACPP_DISCOVERED_ZE_LIBDIR "")
  set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "")
  set(ACPP_DISCOVERED_ZE_BINDIR "")
endif()
