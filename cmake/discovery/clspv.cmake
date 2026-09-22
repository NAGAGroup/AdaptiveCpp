# clspv discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_CLSPV_*. Not found is the normalized empty string.
# clspv is an executable the JIT invokes at application run time, so the
# unit is permissive and the executable is a two-sided resource.

include_guard(GLOBAL)

find_program(ACPP_CLSPV_EXECUTABLE NAMES clspv)

if(ACPP_CLSPV_EXECUTABLE AND NOT "${ACPP_CLSPV_EXECUTABLE}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_CLSPV_FOUND ON)

  get_filename_component(_acpp_clspv_real "${ACPP_CLSPV_EXECUTABLE}" REALPATH)
  set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "${_acpp_clspv_real}")

  get_filename_component(_acpp_clspv_bindir "${_acpp_clspv_real}" DIRECTORY)
  get_filename_component(ACPP_DISCOVERED_CLSPV_PREFIX "${_acpp_clspv_bindir}" DIRECTORY)

  file(RELATIVE_PATH _acpp_clspv_rel "${ACPP_DISCOVERED_CLSPV_PREFIX}" "${_acpp_clspv_bindir}")
  if("${_acpp_clspv_rel}" STREQUAL "" OR "${_acpp_clspv_rel}" MATCHES "^\\.\\.")
    message(FATAL_ERROR
      "ACPP_DISCOVERED_CLSPV_BINDIR: '${_acpp_clspv_bindir}' is not inside "
      "'${ACPP_DISCOVERED_CLSPV_PREFIX}'. The vendor unit deploys in the "
      "distribution's own relative layout; a directory outside the root "
      "has no place in it.")
  endif()
  set(ACPP_DISCOVERED_CLSPV_BINDIR "${_acpp_clspv_rel}")
else()
  set(ACPP_DISCOVERED_CLSPV_FOUND OFF)
  set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "")
  set(ACPP_DISCOVERED_CLSPV_PREFIX "")
  set(ACPP_DISCOVERED_CLSPV_BINDIR "")
endif()
