# Shared functions for verify-install-sync.cmake and its negative-case
# child process (verify-install-sync-inner.cmake) - a text-parse check, not
# the plan-based (ACPP_VENDOR_INSTALL_PLAN) semantic one: building faithful
# fake vendor trees for every acpp_install_vendor_* call across 9 units x 3
# platforms (some calls eager, some deferred, some sharing a fact directory
# between an eager FILES call and a deferrable LIBS call) is substantially
# more machinery than parsing calls whose shape is, by inspection of every
# real cmake/install/*/common/*.cmake file, extremely uniform:
#   acpp_install_vendor_(libs|files|dir)(STEM <S> FACT "<token-or-empty>"
#     [NAMES <names...>] [FILES <names...>] [PROGRAMS <names...>])
# never nested, never with FILES and PROGRAMS in the same call. A manifest
# row and a cmake call each name a vendor/fact/file three ways - "{{ x-y
# -subdir }}" vs "${ACPP_X_Y_SUBDIR}", "{{ libomp-name }}" vs
# "${ACPP_LIBOMP_NAME}", a bare literal name either way - so both sides are
# normalized to one canonical form ("<<VAR:ACPP_X_Y_SUBDIR>>" or a bare
# literal) and then compared as plain strings.
include_guard(GLOBAL)

# One override for the one manifest token whose real cmake variable does
# not follow the mechanical "{{ x-y }}" -> "ACPP_X_Y" rule: the CUDA DLL
# name embeds the *discovered* version, not a toolchain-config key of the
# same name (config/common/cuda.json's own "cuda-version-major" entry
# already says as much: its "value" is "@ACPP_DISCOVERED_CUDA_VERSION_MAJOR@").
function(_acpp_sync_map_token name out_var)
  if("${name}" STREQUAL "cuda-version-major")
    set(${out_var} "ACPP_DISCOVERED_CUDA_VERSION_MAJOR" PARENT_SCOPE)
    return()
  endif()
  string(REPLACE "-" "_" _u "${name}")
  string(TOUPPER "${_u}" _u)
  set(${out_var} "ACPP_${_u}" PARENT_SCOPE)
endfunction()

# "cudart64_{{ cuda-version-major }}" -> "cudart64_<<VAR:ACPP_DISCOVERED_CUDA_VERSION_MAJOR>>".
function(acpp_sync_normalize_manifest_text text out_var)
  set(_t "${text}")
  string(REGEX MATCHALL "{{ *[a-z0-9-]+ *}}" _matches "${_t}")
  list(REMOVE_DUPLICATES _matches)
  foreach(_m IN LISTS _matches)
    string(REGEX REPLACE "{{ *([a-z0-9-]+) *}}" "\\1" _name "${_m}")
    _acpp_sync_map_token("${_name}" _mapped)
    string(REPLACE "${_m}" "<<VAR:${_mapped}>>" _t "${_t}")
  endforeach()
  set(${out_var} "${_t}" PARENT_SCOPE)
endfunction()

# "cudart64_${ACPP_DISCOVERED_CUDA_VERSION_MAJOR}" -> "cudart64_<<VAR:ACPP_DISCOVERED_CUDA_VERSION_MAJOR>>".
function(acpp_sync_normalize_cmake_text text out_var)
  set(_t "${text}")
  string(REGEX MATCHALL "\\$\\{[A-Za-z0-9_]+\\}" _matches "${_t}")
  list(REMOVE_DUPLICATES _matches)
  foreach(_m IN LISTS _matches)
    string(REGEX REPLACE "\\$\\{([A-Za-z0-9_]+)\\}" "\\1" _name "${_m}")
    string(REPLACE "${_m}" "<<VAR:${_name}>>" _t "${_t}")
  endforeach()
  set(${out_var} "${_t}" PARENT_SCOPE)
endfunction()

# A bareword-or-quoted, whitespace-separated name list (an ARGN tail, e.g.
# `amdhip64 hsa-runtime64` or `"${ACPP_LIBOMP_NAME}"`), each entry
# cmake-side normalized.
function(_acpp_sync_split_names text out_var)
  string(REPLACE "\"" "" _clean "${text}")
  string(REGEX REPLACE "[ \t\r\n]+" ";" _clean "${_clean}")
  string(STRIP "${_clean}" _clean)
  set(_out "")
  foreach(_t IN LISTS _clean)
    if(NOT "${_t}" STREQUAL "")
      acpp_sync_normalize_cmake_text("${_t}" _norm)
      list(APPEND _out "${_norm}")
    endif()
  endforeach()
  set(${out_var} "${_out}" PARENT_SCOPE)
endfunction()

# Every acpp_install_vendor_* call in `text`, as a list of
# "STEM|FACT_VAR|KIND|VALUE" entries (KIND one of LIB/FILE/DIR; FACT_VAR a
# bare "ACPP_<STEM>_<X>_SUBDIR" or "" for no fact; VALUE "" for DIR).
function(acpp_sync_parse_install_calls text out_var)
  string(REGEX REPLACE "#[^\n]*" "" _stripped "${text}")
  set(_calls "")
  string(REGEX MATCHALL "acpp_install_vendor_(libs|files|dir)\\([^)]*\\)" _matches "${_stripped}")
  foreach(_m IN LISTS _matches)
    string(REGEX MATCH "acpp_install_vendor_(libs|files|dir)\\(([^)]*)\\)" _ignored "${_m}")
    set(_kind "${CMAKE_MATCH_1}")
    set(_args "${CMAKE_MATCH_2}")

    string(REGEX MATCH "STEM[ \t\r\n]+([A-Za-z0-9_]+)" _ignored2 "${_args}")
    set(_stem "${CMAKE_MATCH_1}")

    string(REGEX MATCH "FACT[ \t\r\n]+\"([^\"]*)\"" _ignored3 "${_args}")
    set(_fact_raw "${CMAKE_MATCH_1}")
    if("${_fact_raw}" STREQUAL "")
      set(_fact_var "")
    else()
      acpp_sync_normalize_cmake_text("${_fact_raw}" _fact_norm)
      string(REGEX REPLACE "^<<VAR:(.*)>>$" "\\1" _fact_var "${_fact_norm}")
    endif()

    if(_kind STREQUAL "libs")
      string(REGEX MATCH "NAMES[ \t\r\n]+(.*)$" _ignored4 "${_args}")
      _acpp_sync_split_names("${CMAKE_MATCH_1}" _names)
      foreach(_n IN LISTS _names)
        list(APPEND _calls "${_stem}|${_fact_var}|LIB|${_n}")
      endforeach()
    elseif(_kind STREQUAL "dir")
      list(APPEND _calls "${_stem}|${_fact_var}|DIR|")
    else()
      # files: PROGRAMS or FILES, never both in the same call (see header).
      if(_args MATCHES "PROGRAMS[ \t\r\n]+(.*)$")
        _acpp_sync_split_names("${CMAKE_MATCH_1}" _names)
      elseif(_args MATCHES "FILES[ \t\r\n]+(.*)$")
        _acpp_sync_split_names("${CMAKE_MATCH_1}" _names)
      else()
        set(_names "")
      endif()
      foreach(_n IN LISTS _names)
        list(APPEND _calls "${_stem}|${_fact_var}|FILE|${_n}")
      endforeach()
    endif()
  endforeach()
  set(${out_var} "${_calls}" PARENT_SCOPE)
endfunction()

# Attributes one manifest row to its owning vendor via the literal
# "{{ <lower>-install-root }}" prefix every external row's "src" begins
# with, and derives the row's FACT_VAR the same way (the second, optional
# "{{ <lower>-<x>-subdir }}" token) - stems is a "STEM:lower" list (from
# acpp_declare_vendor calls; see verify-install-sync.cmake's discovery).
function(acpp_sync_identify_row src stems out_stem out_fact_var)
  foreach(_pair IN LISTS stems)
    string(REPLACE ":" ";" _parts "${_pair}")
    list(GET _parts 0 _stem)
    list(GET _parts 1 _lower)
    set(_root_token "{{ ${_lower}-install-root }}")
    string(FIND "${src}" "${_root_token}" _pos)
    if(_pos EQUAL 0)
      string(LENGTH "${_root_token}" _root_len)
      string(SUBSTRING "${src}" ${_root_len} -1 _rest)
      set(${out_stem} "${_stem}" PARENT_SCOPE)
      if("${_rest}" STREQUAL "")
        set(${out_fact_var} "" PARENT_SCOPE)
      elseif(_rest MATCHES "^/{{ *${_lower}-([a-z]+)-subdir *}}$")
        string(TOUPPER "${CMAKE_MATCH_1}" _x_upper)
        set(${out_fact_var} "ACPP_${_stem}_${_x_upper}_SUBDIR" PARENT_SCOPE)
      else()
        message(FATAL_ERROR "verify-install-sync: unrecognized src shape for ${_stem}: '${src}'")
      endif()
      return()
    endif()
  endforeach()
  message(FATAL_ERROR "verify-install-sync: row src matches no known vendor's install-root token: '${src}'")
endfunction()

# The actual invariant: `wanted` ("STEM|FACT_VAR|KIND|VALUE") must be
# present in `calls` (the parsed install-file calls) - else a manifest row
# names something no acpp_install_vendor_* call provides. FATAL_ERROR
# always terminates the process, so the negative case runs this in a
# child (verify-install-sync-inner.cmake).
function(acpp_sync_require_covered wanted calls context)
  list(FIND calls "${wanted}" _idx)
  if(_idx EQUAL -1)
    message(FATAL_ERROR
      "verify-install-sync: ${context} names '${wanted}' but no "
      "acpp_install_vendor_* call in the install file(s) provides it.")
  endif()
endfunction()
