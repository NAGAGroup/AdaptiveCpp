# OpenCL backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_OCL_*. Not found is the normalized empty string. The unit
# is the ICD loader; the headers are the fetched ones (cmake/fetch.cmake).
#
# Upstream's gate, unchanged: when WITH_SSCP_COMPILER has been explicitly
# turned off, OpenCL is not searched for at all.
#
# find_package(OpenCL) rather than find_library, because the fork adds no
# functionality beyond relocatability and the deployment mechanism:
# upstream's OpenCL is FindOpenCL's, and this unit only redirects where
# FindOpenCL looks for headers, at the fetched copy, so `found` depends on
# the machine's loader alone while FindOpenCL's vendor SDK hints for the
# loader itself still apply.

include_guard(GLOBAL)

if(DEFINED WITH_SSCP_COMPILER AND NOT WITH_SSCP_COMPILER)
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
  return()
endif()

# Apple's OpenCL framework is OpenCL 1.2; the backend compiles against the
# Khronos headers at CL_HPP_TARGET_OPENCL_VERSION 210 and builds programs
# from SPIR-V with cl::Program(context, IL) (src/runtime/ocl/ocl_code_object.cpp
# 71), which needs clCreateProgramWithIL, a 2.1 entry point the framework
# does not export; upstream's macOS CI turns the backend off by hand for
# this reason.
if(APPLE)
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
  set(ACPP_DISCOVERED_OCL_BINDIR "")
  return()
endif()

if(ACPP_FETCHED_OCL_HEADERS_DIR)
  set(OpenCL_INCLUDE_DIR "${ACPP_FETCHED_OCL_HEADERS_DIR}")
endif()

find_package(OpenCL QUIET)

if(OpenCL_FOUND AND OpenCL_LIBRARY AND NOT "${OpenCL_LIBRARY}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_OCL_FOUND ON)

  # find_package answers with the dev symlink; the real file is what deploy
  # copies and what SHARED_LIB: resolves to.
  get_filename_component(_acpp_ocl_real "${OpenCL_LIBRARY}" REALPATH)
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

  # On Windows find_package answers with the import library; the DLL is
  # what deploys and what the runtime must reach through AddDllDirectory.
  # This branch is parse-checked on Linux and exercised on Windows only.
  if(WIN32)
    find_file(ACPP_OCL_LOADER_DLL NAMES OpenCL.dll
      HINTS "${ACPP_DISCOVERED_OCL_PREFIX}/bin" NO_DEFAULT_PATH)
    if(NOT ACPP_OCL_LOADER_DLL OR "${ACPP_OCL_LOADER_DLL}" MATCHES "-NOTFOUND$")
      message(FATAL_ERROR
        "OpenCL import library found at ${OpenCL_LIBRARY} but "
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
