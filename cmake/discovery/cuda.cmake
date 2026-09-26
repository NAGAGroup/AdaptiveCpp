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

# Probing happens first, into locals: found-but-incomplete (libdevice
# missing) must not FATAL_ERROR now that discovery runs unconditionally -
# it warns and the export below lands in the same not-found state as
# CUDAToolkit not being found at all. Explicitly requesting the backend
# still fails, from the root's own WITH_CUDA_BACKEND check.
set(_acpp_cuda_usable OFF)
if(CUDAToolkit_FOUND)
  list(GET CUDAToolkit_INCLUDE_DIRS 0 _acpp_cuda_incdir)

  # Upstream's -DCUDA_DEVICE_LIBS_PATH, honoured first, like
  # ROCM_DEVICE_LIBS_PATH for HIP.
  if(DEFINED CUDA_DEVICE_LIBS_PATH AND NOT "${CUDA_DEVICE_LIBS_PATH}" STREQUAL ""
      AND EXISTS "${CUDA_DEVICE_LIBS_PATH}/libdevice.10.bc")
    set(_acpp_cuda_libdevice_dir "${CUDA_DEVICE_LIBS_PATH}")
  else()
    # libdevice: the generic JIT cannot target CUDA without it. The toolkit's
    # own root is a search hint here, not an asserted prefix - the common
    # ancestor below is what the prefix actually becomes.
    set(_acpp_cuda_libdevice_dir "${CUDAToolkit_LIBRARY_ROOT}/nvvm/libdevice")
  endif()
  if(EXISTS "${_acpp_cuda_libdevice_dir}/libdevice.10.bc")
    set(_acpp_cuda_usable ON)
  else()
    message(WARNING
      "The generic JIT cannot target CUDA without libdevice. Expected "
      "${_acpp_cuda_libdevice_dir}/libdevice.10.bc to exist. Point "
      "-DCUDA_DEVICE_LIBS_PATH at the directory holding libdevice.10.bc. "
      "CUDA support is disabled.")
  endif()
endif()

if(CUDAToolkit_FOUND AND _acpp_cuda_usable)
  set(ACPP_DISCOVERED_CUDA_FOUND ON)
  set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "${CUDAToolkit_VERSION_MAJOR}")
  set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "${CUDAToolkit_VERSION_MINOR}")

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
