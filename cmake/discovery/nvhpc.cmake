# HPC SDK runtime discovery.
#
# Loaded by cmake/discovery.cmake alongside the nvcxx flow; exports
# ACPP_DISCOVERED_NVHPC_*. Not found is the normalized empty string.
#
# The HPC SDK is a separate product from the CUDA toolkit with its own
# terms and lifecycle. Its redistributable runtime lives at
# <sdk-root>/REDIST/compilers/lib, a subset of <sdk-root>/compilers/lib.

include_guard(GLOBAL)

find_program(_acpp_nvhpc_nvcxx NAMES nvc++)

if(_acpp_nvhpc_nvcxx)
  # Resolve symlinks so the SDK root derivation sees the real installation.
  get_filename_component(_acpp_nvhpc_real "${_acpp_nvhpc_nvcxx}" REALPATH)
  # <root>/compilers/bin/nvc++ -> two directories up is the SDK root.
  get_filename_component(_acpp_nvhpc_bindir "${_acpp_nvhpc_real}" DIRECTORY)
  get_filename_component(_acpp_nvhpc_compilers "${_acpp_nvhpc_bindir}" DIRECTORY)
  get_filename_component(_acpp_nvhpc_root "${_acpp_nvhpc_compilers}" DIRECTORY)

  set(ACPP_DISCOVERED_NVHPC_FOUND ON)
  set(ACPP_DISCOVERED_NVHPC_NVCXX "${_acpp_nvhpc_real}")
  set(ACPP_DISCOVERED_NVHPC_PREFIX "${_acpp_nvhpc_root}/REDIST")
  set(ACPP_DISCOVERED_NVHPC_LIBDIR "compilers/lib")

  if(NOT IS_DIRECTORY "${ACPP_DISCOVERED_NVHPC_PREFIX}/${ACPP_DISCOVERED_NVHPC_LIBDIR}")
    message(FATAL_ERROR
      "nvc++ was found at ${_acpp_nvhpc_real} but its redistributable "
      "runtime (${ACPP_DISCOVERED_NVHPC_PREFIX}/${ACPP_DISCOVERED_NVHPC_LIBDIR}) "
      "was not. The nvcxx flow cannot be deployed without it.")
  endif()

  # Version: parse nvc++ --version output.
  execute_process(
    COMMAND "${_acpp_nvhpc_real}" --version
    OUTPUT_VARIABLE _acpp_nvhpc_ver_out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if("${_acpp_nvhpc_ver_out}" MATCHES "nvc\\+\\+ ([0-9]+)\\.([0-9]+)")
    set(ACPP_DISCOVERED_NVHPC_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(ACPP_DISCOVERED_NVHPC_VERSION_MINOR "${CMAKE_MATCH_2}")
  else()
    set(ACPP_DISCOVERED_NVHPC_VERSION_MAJOR "")
    set(ACPP_DISCOVERED_NVHPC_VERSION_MINOR "")
  endif()
else()
  set(ACPP_DISCOVERED_NVHPC_FOUND OFF)
  set(ACPP_DISCOVERED_NVHPC_NVCXX "")
  set(ACPP_DISCOVERED_NVHPC_PREFIX "")
  set(ACPP_DISCOVERED_NVHPC_LIBDIR "")
  set(ACPP_DISCOVERED_NVHPC_VERSION_MAJOR "")
  set(ACPP_DISCOVERED_NVHPC_VERSION_MINOR "")
endif()
