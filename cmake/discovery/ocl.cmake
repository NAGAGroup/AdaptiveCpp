# OpenCL backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_OCL_*. Not found is the normalized empty string.
#
# Upstream's find, moved here unchanged except for the 2.1 minimum: it
# runs behind the WITH_SSCP_COMPILER gate, against the machine's own
# OpenCL headers and library, which ship as a pair, so the version this
# reads is the machine's own. 2.1 is the lowest version the backend links
# against (CL-HPP at target 210, SVM from 2.0, clCreateProgramWithIL from
# 2.1), which rejects a 1.2 implementation - such as Apple's OpenCL
# framework - the same way on every platform; no platform-specific code is
# needed. The fetched Khronos headers (cmake/fetch.cmake) run after this
# and only compile the backend; they never decide whether OpenCL is found.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

if(DEFINED WITH_SSCP_COMPILER AND NOT WITH_SSCP_COMPILER)
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
  return()
endif()

find_package(OpenCL 2.1 QUIET)

if(OpenCL_FOUND AND OpenCL_LIBRARY AND NOT "${OpenCL_LIBRARY}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_OCL_FOUND ON)

  # find_package answers with the dev symlink; the real file is what deploy
  # copies and what SHARED_LIB: resolves to.
  get_filename_component(_acpp_ocl_real "${OpenCL_LIBRARY}" REALPATH)
  set(ACPP_DISCOVERED_OCL_LOADER "${_acpp_ocl_real}")
  get_filename_component(_acpp_ocl_libdir "${_acpp_ocl_real}" DIRECTORY)

  # On Windows find_package answers with the import library; the DLL is
  # what deploys and what the runtime must reach through AddDllDirectory.
  # This branch is parse-checked on Linux and exercised on Windows only.
  # The search hint is the libdir's own parent, a guess, not an asserted
  # prefix - the common ancestor below settles it regardless of whether
  # the guess was right.
  if(WIN32)
    get_filename_component(_acpp_ocl_hint "${_acpp_ocl_libdir}" DIRECTORY)
    find_file(ACPP_OCL_LOADER_DLL NAMES OpenCL.dll
      HINTS "${_acpp_ocl_hint}/bin" NO_DEFAULT_PATH)
    if(NOT ACPP_OCL_LOADER_DLL OR "${ACPP_OCL_LOADER_DLL}" MATCHES "-NOTFOUND$")
      message(FATAL_ERROR
        "OpenCL import library found at ${OpenCL_LIBRARY} but "
        "OpenCL.dll was not found in ${_acpp_ocl_hint}/bin")
    endif()
    get_filename_component(_acpp_ocl_dlldir "${ACPP_OCL_LOADER_DLL}" DIRECTORY)

    acpp_common_ancestor(ACPP_DISCOVERED_OCL_PREFIX
      "${_acpp_ocl_libdir}" "${_acpp_ocl_dlldir}")
    file(RELATIVE_PATH ACPP_DISCOVERED_OCL_BINDIR
      "${ACPP_DISCOVERED_OCL_PREFIX}" "${_acpp_ocl_dlldir}")
  else()
    acpp_common_ancestor(ACPP_DISCOVERED_OCL_PREFIX "${_acpp_ocl_libdir}")
    set(ACPP_DISCOVERED_OCL_BINDIR "")
  endif()

  file(RELATIVE_PATH ACPP_DISCOVERED_OCL_LIBDIR
    "${ACPP_DISCOVERED_OCL_PREFIX}" "${_acpp_ocl_libdir}")
else()
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
endif()
