# clspv discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_CLSPV_*. Not found is the normalized empty string.
# clspv is an executable the JIT invokes at application run time, so the
# unit is permissive and the executable is a two-sided resource.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

find_program(ACPP_CLSPV_EXECUTABLE NAMES clspv)

if(ACPP_CLSPV_EXECUTABLE AND NOT "${ACPP_CLSPV_EXECUTABLE}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_CLSPV_FOUND ON)

  get_filename_component(_acpp_clspv_real "${ACPP_CLSPV_EXECUTABLE}" REALPATH)
  set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "${_acpp_clspv_real}")
  get_filename_component(_acpp_clspv_bindir "${_acpp_clspv_real}" DIRECTORY)

  acpp_common_ancestor(ACPP_DISCOVERED_CLSPV_PREFIX "${_acpp_clspv_bindir}")
  file(RELATIVE_PATH ACPP_DISCOVERED_CLSPV_BINDIR
    "${ACPP_DISCOVERED_CLSPV_PREFIX}" "${_acpp_clspv_bindir}")
else()
  set(ACPP_DISCOVERED_CLSPV_FOUND OFF)
  set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "")
  set(ACPP_DISCOVERED_CLSPV_PREFIX "")
  set(ACPP_DISCOVERED_CLSPV_BINDIR "")
endif()
