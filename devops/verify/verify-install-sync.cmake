cmake_minimum_required(VERSION 3.19)

# The sync check: every vendor unit's manifest rows (config/<tiers>/deploy/
# <unit>.json's external-permissive/external-nonpermissive groups) must be
# covered by that unit's cmake install file (cmake/install/<platform>/
# common/<unit>.cmake, plus cmake/install/<platform>/<arch>/core.cmake for
# core - svml's row lives in the arch-tier fragment/install file, not the
# common one). Run with cmake -P:
#   cmake -P devops/verify/verify-install-sync.cmake
#
# Approach: a careful text parse (see verify-install-sync-lib.cmake's own
# header for why this was chosen over the plan-based/ACPP_VENDOR_INSTALL_
# PLAN semantic check verify-vendor-install.cmake already uses for a
# smaller, hand-picked set of vendors). Both a manifest row's tokens
# ("{{ x-y-subdir }}", "{{ libomp-name }}") and an install call's
# ("${ACPP_X_Y_SUBDIR}", "${ACPP_LIBOMP_NAME}") are normalized to one
# canonical form and compared as plain strings - no fake filesystem, no
# vendor discovery stand-ins, nothing executed that could itself silently
# no-op (acpp_install_vendor_* are never even called - their *text* is
# parsed, so a missing/renamed call is caught the same as a missing file
# would be).
#
# The unit -> STEM/lower mapping used to attribute a row to its vendor
# comes from cmake/options/**/*.cmake's own acpp_declare_vendor(<STEM>
# <lower> <category>) calls - not a hand-written table.
#
# Uncovered-by-manifest install calls (the toolchain-only pieces: headers,
# ptxas-class tools, import libraries) are not a failure - listed in the
# output instead, per unit.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-config-merge.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/verify-install-sync-lib.cmake)

# ---------------------------------------------------------------------------
# Discover STEM:lower pairs from every acpp_declare_vendor(<STEM> <lower>
# <category>) call under cmake/options/.
# ---------------------------------------------------------------------------

file(GLOB_RECURSE _option_files "${ACPP_REPO_ROOT}/cmake/options/*.cmake")
set(_stems "")
set(_seen_stems "")
foreach(_f IN LISTS _option_files)
  file(READ "${_f}" _text)
  string(REGEX REPLACE "#[^\n]*" "" _text "${_text}")
  string(REGEX MATCHALL "acpp_declare_vendor\\([A-Za-z0-9_]+ [a-z0-9_]+ (non)?permissive( [^)]*)?\\)" _matches "${_text}")
  foreach(_m IN LISTS _matches)
    string(REGEX MATCH "acpp_declare_vendor\\(([A-Za-z0-9_]+) ([a-z0-9_]+) ((non)?permissive)( [^)]*)?\\)" _ignored "${_m}")
    set(_stem "${CMAKE_MATCH_1}")
    set(_lower "${CMAKE_MATCH_2}")
    list(FIND _seen_stems "${_stem}" _idx)
    if(_idx EQUAL -1)
      list(APPEND _seen_stems "${_stem}")
      list(APPEND _stems "${_stem}:${_lower}")
    endif()
  endforeach()
endforeach()
if(NOT _stems)
  message(FATAL_ERROR "verify-install-sync: discovered zero vendor stems - acpp_declare_vendor's call shape must have changed")
endif()
list(LENGTH _stems _nstems)
message(STATUS "verify-install-sync: discovered ${_nstems} vendor stem(s) from acpp_declare_vendor calls")

# ---------------------------------------------------------------------------
# Check one (platform, arch, unit): merge its deploy fragment, attribute
# every external-permissive/external-nonpermissive row to a vendor, and
# require an install call covering it. Reports (STATUS, not a failure)
# whichever install calls no row ever claimed.
# ---------------------------------------------------------------------------

function(acpp_sync_check_unit platform arch unit install_texts)
  acpp_merge_unit("deploy" "${platform}" "${arch}" "${unit}" _merged)

  set(_calls "")
  foreach(_text IN LISTS install_texts)
    acpp_sync_parse_install_calls("${_text}" _these)
    list(APPEND _calls ${_these})
  endforeach()
  set(_remaining "${_calls}")

  foreach(_group external-permissive external-nonpermissive)
    string(JSON _rows ERROR_VARIABLE _err GET "${_merged}" "${_group}")
    if(_err)
      continue()
    endif()
    string(JSON _n LENGTH "${_rows}")
    if(_n EQUAL 0)
      continue()
    endif()
    math(EXPR _last "${_n} - 1")
    foreach(_i RANGE 0 ${_last})
      string(JSON _row GET "${_rows}" ${_i})
      string(JSON _src GET "${_row}" "src")
      string(JSON _files GET "${_row}" "files")

      acpp_sync_identify_row("${_src}" "${_stems}" _stem _fact_var)

      string(JSON _nf LENGTH "${_files}")
      if(_nf GREATER 0)
        math(EXPR _flast "${_nf} - 1")
        foreach(_fi RANGE 0 ${_flast})
          string(JSON _entry GET "${_files}" ${_fi})
          if("${_entry}" STREQUAL "*")
            set(_wanted "${_stem}|${_fact_var}|DIR|")
          elseif(_entry MATCHES "^SHARED_LIB:(.*)$")
            acpp_sync_normalize_manifest_text("${CMAKE_MATCH_1}" _value)
            set(_wanted "${_stem}|${_fact_var}|LIB|${_value}")
          else()
            acpp_sync_normalize_manifest_text("${_entry}" _value)
            set(_wanted "${_stem}|${_fact_var}|FILE|${_value}")
          endif()

          acpp_sync_require_covered("${_wanted}" "${_calls}"
            "${platform}/${arch}/${unit}.json ${_group}[${_i}]")
          list(REMOVE_ITEM _remaining "${_wanted}")
        endforeach()
      endif()
    endforeach()
  endforeach()

  foreach(_c IN LISTS _remaining)
    message(STATUS "  (no manifest row - toolchain-only) ${platform}/${unit}: ${_c}")
  endforeach()
endfunction()

# ---------------------------------------------------------------------------
# Drive every (platform, arch) x unit combination - the same platform/arch
# list verify-common.cmake uses.
# ---------------------------------------------------------------------------

set(_platforms_archs
  linux    x86_64
  linux    aarch64
  windows  x86_64
  windows  aarch64
  macos    arm64)

list(LENGTH _platforms_archs _pa_len)
math(EXPR _pa_last "${_pa_len} - 2")
foreach(_i RANGE 0 ${_pa_last} 2)
  math(EXPR _j "${_i} + 1")
  list(GET _platforms_archs ${_i} _platform)
  list(GET _platforms_archs ${_j} _arch)

  set(_deploy_dir "${ACPP_REPO_ROOT}/config/${_platform}/common/deploy")
  if(NOT IS_DIRECTORY "${_deploy_dir}")
    continue()
  endif()
  file(GLOB _unit_files RELATIVE "${_deploy_dir}" "${_deploy_dir}/*.json")

  foreach(_uf IN LISTS _unit_files)
    string(REGEX REPLACE "\\.json$" "" _unit "${_uf}")

    set(_install_texts "")
    set(_common_install "${ACPP_REPO_ROOT}/cmake/install/${_platform}/common/${_unit}.cmake")
    if(EXISTS "${_common_install}")
      file(READ "${_common_install}" _t)
      list(APPEND _install_texts "${_t}")
    endif()
    if("${_unit}" STREQUAL "core")
      set(_arch_install "${ACPP_REPO_ROOT}/cmake/install/${_platform}/${_arch}/core.cmake")
      if(EXISTS "${_arch_install}")
        file(READ "${_arch_install}" _t2)
        list(APPEND _install_texts "${_t2}")
      endif()
    endif()

    acpp_sync_check_unit("${_platform}" "${_arch}" "${_unit}" "${_install_texts}")
  endforeach()

  message(STATUS "${_platform}/${_arch}: every manifest row is covered by an install call")
endforeach()

# ---------------------------------------------------------------------------
# Negative case: a scratch row naming a file no install call provides must
# fail - in a child process (FATAL_ERROR has no in-process way to be
# caught, same reasoning verify-vendor-install.cmake's own negative case
# documents).
# ---------------------------------------------------------------------------

execute_process(
  COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_LIST_DIR}/verify-install-sync-inner.cmake"
  OUTPUT_VARIABLE _neg_out ERROR_VARIABLE _neg_err RESULT_VARIABLE _neg_res)
if(_neg_res EQUAL 0)
  message(FATAL_ERROR
    "negative case: an uncovered scratch row should have failed but exited 0:\n${_neg_out}\n${_neg_err}")
endif()
if(NOT "${_neg_err}" MATCHES "doesnotexist")
  message(FATAL_ERROR
    "negative case: failed, but not for the uncovered-row reason:\n${_neg_err}")
endif()
message(STATUS "verify-install-sync: an uncovered manifest row is a configure error, as declared")

message(STATUS "verify-install-sync: all checks passed")
