# CUDA backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_CUDA_*. Not found is the normalized empty string.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# Let upstream's CUDA_TOOLKIT_ROOT_DIR spelling work.
if(DEFINED CUDA_TOOLKIT_ROOT_DIR AND NOT DEFINED CUDAToolkit_ROOT)
  set(CUDAToolkit_ROOT "${CUDA_TOOLKIT_ROOT_DIR}")
endif()

find_package(CUDAToolkit QUIET)

if(CUDAToolkit_FOUND)
  set(ACPP_DISCOVERED_CUDA_FOUND ON)
  set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "${CUDAToolkit_VERSION_MAJOR}")
  set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "${CUDAToolkit_VERSION_MINOR}")

  list(GET CUDAToolkit_INCLUDE_DIRS 0 _acpp_cuda_incdir)

  # libdevice: the generic JIT cannot target CUDA without it. The toolkit's
  # own root is a search hint here, not an asserted prefix - the common
  # ancestor below is what the prefix actually becomes.
  set(_acpp_cuda_libdevice_dir "${CUDAToolkit_LIBRARY_ROOT}/nvvm/libdevice")
  if(NOT EXISTS "${_acpp_cuda_libdevice_dir}/libdevice.10.bc")
    message(FATAL_ERROR
      "The generic JIT cannot target CUDA without libdevice. Expected "
      "${_acpp_cuda_libdevice_dir}/libdevice.10.bc to exist.")
  endif()

  # The prefix is derived, not asserted: the common ancestor of every
  # piece discovery actually found. A layout that does not match the
  # toolkit's own convention (conda splits runtime libraries away from
  # $CUDAToolkit_LIBRARY_ROOT/lib, for instance) still configures.
  acpp_common_ancestor(ACPP_DISCOVERED_CUDA_PREFIX
    "${CUDAToolkit_LIBRARY_DIR}"
    "${CUDAToolkit_BIN_DIR}"
    "${_acpp_cuda_incdir}"
    "${_acpp_cuda_libdevice_dir}")

  file(RELATIVE_PATH ACPP_DISCOVERED_CUDA_LIBDIR
    "${ACPP_DISCOVERED_CUDA_PREFIX}" "${CUDAToolkit_LIBRARY_DIR}")
  file(RELATIVE_PATH ACPP_DISCOVERED_CUDA_BINDIR
    "${ACPP_DISCOVERED_CUDA_PREFIX}" "${CUDAToolkit_BIN_DIR}")
  file(RELATIVE_PATH ACPP_DISCOVERED_CUDA_INCDIR
    "${ACPP_DISCOVERED_CUDA_PREFIX}" "${_acpp_cuda_incdir}")
  file(RELATIVE_PATH ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR
    "${ACPP_DISCOVERED_CUDA_PREFIX}" "${_acpp_cuda_libdevice_dir}")
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
