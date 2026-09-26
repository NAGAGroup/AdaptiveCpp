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

# Probing happens first, into locals: found-but-incomplete (on Windows, the
# import library found but ze_loader.dll missing) must not FATAL_ERROR now
# that discovery runs unconditionally - it warns and the export below
# lands in the same not-found state as the loader not being found at all.
# Explicitly requesting the backend still fails, from the root's own check.
set(_acpp_ze_usable OFF)
if(ACPP_ZE_LOADER_LIBRARY AND NOT "${ACPP_ZE_LOADER_LIBRARY}" MATCHES "-NOTFOUND$"
    AND ACPP_ZE_INCLUDE_DIR AND NOT "${ACPP_ZE_INCLUDE_DIR}" MATCHES "-NOTFOUND$")
  # find_library answers with the dev symlink; the real file is what deploy
  # copies and what SHARED_LIB: resolves to.
  get_filename_component(_acpp_ze_real "${ACPP_ZE_LOADER_LIBRARY}" REALPATH)
  get_filename_component(_acpp_ze_libdir "${_acpp_ze_real}" DIRECTORY)

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
      message(WARNING
        "ze_loader import library found at ${ACPP_ZE_LOADER_LIBRARY} but "
        "ze_loader.dll was not found in ${_acpp_ze_hint}/bin. Level Zero "
        "support is disabled.")
    else()
      set(_acpp_ze_usable ON)
    endif()
  else()
    set(_acpp_ze_usable ON)
  endif()
endif()

if(_acpp_ze_usable)
  set(ACPP_DISCOVERED_ZE_FOUND ON)
  set(ACPP_DISCOVERED_ZE_LOADER "${_acpp_ze_real}")

  # Build-only: consumed by the runtime target's include directories, never
  # written to the configuration.
  set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "${ACPP_ZE_INCLUDE_DIR}")

  if(WIN32)
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
