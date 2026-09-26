# HPC SDK runtime discovery.
#
# Loaded by cmake/discovery.cmake alongside the nvcxx flow; exports
# ACPP_DISCOVERED_NVHPC_*. Not found is the normalized empty string.
#
# The HPC SDK is a separate product from the CUDA toolkit with its own
# terms and lifecycle. Its redistributable runtime lives at
# <sdk-root>/REDIST/compilers/lib, a subset of <sdk-root>/compilers/lib.

include_guard(GLOBAL)

# Upstream's cache name, so -DNVCXX_COMPILER= works as it did there.
find_program(NVCXX_COMPILER NAMES nvc++)

# Probing happens first, into locals: found-but-incomplete (nvc++ found but
# no REDIST runtime) must not FATAL_ERROR now that discovery runs
# unconditionally - it warns and the export below lands in the same
# not-found state as nvc++ not being found at all. Explicitly requesting
# the nvcxx flow still fails, from the root's own check.
set(_acpp_nvhpc_usable OFF)
if(NVCXX_COMPILER AND NOT NVCXX_COMPILER MATCHES "-NOTFOUND$")
  # Resolve symlinks so the SDK root derivation sees the real installation.
  get_filename_component(_acpp_nvhpc_real "${NVCXX_COMPILER}" REALPATH)
  # <root>/compilers/bin/nvc++ -> two directories up is the SDK root.
  get_filename_component(_acpp_nvhpc_bindir "${_acpp_nvhpc_real}" DIRECTORY)
  get_filename_component(_acpp_nvhpc_compilers "${_acpp_nvhpc_bindir}" DIRECTORY)
  get_filename_component(_acpp_nvhpc_root "${_acpp_nvhpc_compilers}" DIRECTORY)

  set(_acpp_nvhpc_prefix "${_acpp_nvhpc_root}/REDIST")
  set(_acpp_nvhpc_libdir "compilers/lib")

  if(IS_DIRECTORY "${_acpp_nvhpc_prefix}/${_acpp_nvhpc_libdir}")
    set(_acpp_nvhpc_usable ON)
  else()
    message(WARNING
      "nvc++ was found at ${_acpp_nvhpc_real} but its redistributable "
      "runtime (${_acpp_nvhpc_prefix}/${_acpp_nvhpc_libdir}) "
      "was not. The nvcxx flow cannot be deployed without it. nvhpc "
      "support is disabled.")
  endif()
endif()

if(_acpp_nvhpc_usable)
  set(ACPP_DISCOVERED_NVHPC_FOUND ON)
  set(ACPP_DISCOVERED_NVHPC_NVCXX "${_acpp_nvhpc_real}")
  set(ACPP_DISCOVERED_NVHPC_PREFIX "${_acpp_nvhpc_prefix}")
  set(ACPP_DISCOVERED_NVHPC_LIBDIR "${_acpp_nvhpc_libdir}")

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
