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
else()
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
  set(ACPP_DISCOVERED_OCL_LOADER "")
  set(ACPP_DISCOVERED_OCL_PREFIX "")
  set(ACPP_DISCOVERED_OCL_LIBDIR "")
endif()
