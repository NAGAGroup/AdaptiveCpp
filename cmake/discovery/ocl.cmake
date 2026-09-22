# OpenCL backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_OCL_*. Not found is the normalized empty string.
# The unit is the ICD loader and nothing else.
#
# find_library rather than FindOpenCL because the headers are ours
# (FetchContent'd from Khronos) and the loader is the only thing the
# machine supplies. FindOpenCL's REQUIRED_VARS include OpenCL_INCLUDE_DIR,
# which we never use, and its version comes from whichever system headers
# it finds, which is neither the loader nor what we compile against.

include_guard(GLOBAL)

# Apple's OpenCL framework is what find_library would return on macOS, and
# it is deprecated, is not an ICD loader and accepts no SPIR-V. The OpenCL
# unit does not exist on macOS.
if(APPLE)
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
  return()
endif()

find_library(ACPP_OCL_LOADER_LIBRARY NAMES OpenCL)

if(ACPP_OCL_LOADER_LIBRARY AND NOT "${ACPP_OCL_LOADER_LIBRARY}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_OCL_FOUND ON)

  # find_library answers with the dev symlink; the real file is what deploy
  # copies and what SHARED_LIB: resolves to.
  get_filename_component(_acpp_ocl_real "${ACPP_OCL_LOADER_LIBRARY}" REALPATH)
  set(ACPP_DISCOVERED_OCL_LOADER "${_acpp_ocl_real}")

  get_filename_component(_acpp_ocl_libdir "${_acpp_ocl_real}" DIRECTORY)
  get_filename_component(ACPP_DISCOVERED_OCL_PREFIX "${_acpp_ocl_libdir}" DIRECTORY)

  file(RELATIVE_PATH _acpp_ocl_rel "${ACPP_DISCOVERED_OCL_PREFIX}" "${_acpp_ocl_libdir}")
  if("${_acpp_ocl_rel}" STREQUAL "" OR "${_acpp_ocl_rel}" MATCHES "^\\.\\.")
    message(FATAL_ERROR
      "ACPP_DISCOVERED_OCL_LIBDIR: '${_acpp_ocl_libdir}' is not inside "
      "'${ACPP_DISCOVERED_OCL_PREFIX}'. The vendor unit deploys in the "
      "distribution's own relative layout; a directory outside the root "
      "has no place in it.")
  endif()
  set(ACPP_DISCOVERED_OCL_LIBDIR "${_acpp_ocl_rel}")

  # On Windows find_library answers with the import library; the DLL is what
  # deploys and what the runtime must reach through AddDllDirectory. This
  # branch is parse-checked on Linux and exercised on Windows only.
  if(WIN32)
    find_file(ACPP_OCL_LOADER_DLL NAMES OpenCL.dll
      HINTS "${ACPP_DISCOVERED_OCL_PREFIX}/bin" NO_DEFAULT_PATH)
    if(NOT ACPP_OCL_LOADER_DLL OR "${ACPP_OCL_LOADER_DLL}" MATCHES "-NOTFOUND$")
      message(FATAL_ERROR
        "OpenCL import library found at ${ACPP_OCL_LOADER_LIBRARY} but "
        "OpenCL.dll was not found in ${ACPP_DISCOVERED_OCL_PREFIX}/bin")
    endif()
    get_filename_component(_acpp_ocl_dlldir "${ACPP_OCL_LOADER_DLL}" DIRECTORY)
    file(RELATIVE_PATH _acpp_ocl_binrel "${ACPP_DISCOVERED_OCL_PREFIX}" "${_acpp_ocl_dlldir}")
    if("${_acpp_ocl_binrel}" STREQUAL "" OR "${_acpp_ocl_binrel}" MATCHES "^\\.\\.")
      message(FATAL_ERROR
        "ACPP_DISCOVERED_OCL_BINDIR: '${_acpp_ocl_dlldir}' is not inside "
        "'${ACPP_DISCOVERED_OCL_PREFIX}'.")
    endif()
    set(ACPP_DISCOVERED_OCL_BINDIR "${_acpp_ocl_binrel}")
  else()
    set(ACPP_DISCOVERED_OCL_BINDIR "")
  endif()
else()
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
endif()
