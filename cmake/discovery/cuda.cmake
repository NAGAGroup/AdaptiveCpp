# CUDA backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_CUDA_*. Not found is the normalized empty string.

include_guard(GLOBAL)

# Let upstream's CUDA_TOOLKIT_ROOT_DIR spelling work.
if(DEFINED CUDA_TOOLKIT_ROOT_DIR AND NOT DEFINED CUDAToolkit_ROOT)
  set(CUDAToolkit_ROOT "${CUDA_TOOLKIT_ROOT_DIR}")
endif()

find_package(CUDAToolkit QUIET)

if(CUDAToolkit_FOUND)
  set(ACPP_DISCOVERED_CUDA_FOUND ON)
  set(ACPP_DISCOVERED_CUDA_PREFIX "${CUDAToolkit_LIBRARY_ROOT}")
  set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "${CUDAToolkit_VERSION_MAJOR}")
  set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "${CUDAToolkit_VERSION_MINOR}")

  # Relative facts: the vendor unit is installed in the toolkit's own
  # relative layout. A directory outside the root has no place in it.
  foreach(_acpp_cuda_pair
      "ACPP_DISCOVERED_CUDA_LIBDIR;${CUDAToolkit_LIBRARY_DIR}"
      "ACPP_DISCOVERED_CUDA_BINDIR;${CUDAToolkit_BIN_DIR}")
    list(GET _acpp_cuda_pair 0 _acpp_cuda_var)
    list(GET _acpp_cuda_pair 1 _acpp_cuda_dir)
    file(RELATIVE_PATH _acpp_cuda_rel "${CUDAToolkit_LIBRARY_ROOT}" "${_acpp_cuda_dir}")
    if("${_acpp_cuda_rel}" STREQUAL "" OR "${_acpp_cuda_rel}" MATCHES "^\\.\\.")
      message(FATAL_ERROR
        "${_acpp_cuda_var}: '${_acpp_cuda_dir}' is not inside '${CUDAToolkit_LIBRARY_ROOT}'. "
        "The vendor unit deploys in the toolkit's own relative layout; a "
        "directory outside the root has no place in it.")
    endif()
    set(${_acpp_cuda_var} "${_acpp_cuda_rel}")
  endforeach()

  # Include directory: take the first element.
  list(GET CUDAToolkit_INCLUDE_DIRS 0 _acpp_cuda_inc)
  file(RELATIVE_PATH _acpp_cuda_inc_rel "${CUDAToolkit_LIBRARY_ROOT}" "${_acpp_cuda_inc}")
  if("${_acpp_cuda_inc_rel}" STREQUAL "" OR "${_acpp_cuda_inc_rel}" MATCHES "^\\.\\.")
    message(FATAL_ERROR
      "ACPP_DISCOVERED_CUDA_INCDIR: '${_acpp_cuda_inc}' is not inside "
      "'${CUDAToolkit_LIBRARY_ROOT}'.")
  endif()
  set(ACPP_DISCOVERED_CUDA_INCDIR "${_acpp_cuda_inc_rel}")

  # libdevice: the generic JIT cannot target CUDA without it.
  set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR
      "${CUDAToolkit_LIBRARY_ROOT}/nvvm/libdevice")
  if(NOT EXISTS "${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}/libdevice.10.bc")
    message(FATAL_ERROR
      "The generic JIT cannot target CUDA without libdevice. Expected "
      "${ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR}/libdevice.10.bc to exist.")
  endif()
else()
  set(ACPP_DISCOVERED_CUDA_FOUND OFF)
  set(ACPP_DISCOVERED_CUDA_PREFIX "")
  set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "")
  set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "")
  set(ACPP_DISCOVERED_CUDA_LIBDIR "")
  set(ACPP_DISCOVERED_CUDA_INCDIR "")
  set(ACPP_DISCOVERED_CUDA_BINDIR "")
  set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "")
endif()
