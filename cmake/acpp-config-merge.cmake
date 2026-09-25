# The tiered configuration merge, shared by the harnesses and (from later
# steps of Commit 3) the actual build - config/common -> config/<platform>/
# common -> config/<platform>/<arch>, for three kinds of fragment: `config`
# (the toolchain-config json objects, config/<platform>/<arch>/<unit>.json),
# `deploy` (the deploy manifests, .../deploy/<unit>.json) and `app` (the
# application-config .cfg fragments, .../app/<unit>.cfg).
#
# include_guard(GLOBAL): safe to include from more than one harness (or
# from the harness and the build) in the same cmake -P / configure process.
#
# Repo root is computed once, here, from this file's own location -
# CMAKE_CURRENT_LIST_DIR at file scope (not inside a function) is always
# this file's own directory, regardless of who includes it or from where.
# Nothing below reads a harness-local ACPP_REPO_ROOT or any other
# harness-local variable.

include_guard(GLOBAL)

get_filename_component(_ACPP_MERGE_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

# ---------------------------------------------------------------------------
# JSON object merge: union of members. FATAL_ERROR on a duplicate key.
# ---------------------------------------------------------------------------
function(acpp_merge_json_objects result_var base overlay overlay_label)
  set(_result "${base}")
  string(JSON _len LENGTH "${overlay}")
  if(_len GREATER 0)
    math(EXPR _last "${_len} - 1")
    foreach(_i RANGE 0 ${_last})
      string(JSON _key MEMBER "${overlay}" ${_i})
      string(JSON _val GET "${overlay}" "${_key}")
      # Check if key already exists in result
      string(JSON _probe ERROR_VARIABLE _err GET "${_result}" "${_key}")
      if(NOT _err)
        message(FATAL_ERROR
          "Duplicate key '${_key}' in ${overlay_label}: already present in an earlier tier")
      endif()
      string(JSON _result SET "${_result}" "${_key}" "${_val}")
    endforeach()
  endif()
  set(${result_var} "${_result}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# JSON array merge: concatenation, in order.
# ---------------------------------------------------------------------------
function(acpp_concat_json_arrays result_var base addition)
  set(_result "${base}")
  string(JSON _add_len LENGTH "${addition}")
  if(_add_len GREATER 0)
    math(EXPR _add_last "${_add_len} - 1")
    foreach(_i RANGE 0 ${_add_last})
      string(JSON _elem GET "${addition}" ${_i})
      string(JSON _base_len LENGTH "${_result}")
      string(JSON _result SET "${_result}" ${_base_len} "${_elem}")
    endforeach()
  endif()
  set(${result_var} "${_result}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# JSON array de-duplication: drop an element that is structurally EQUAL to
# one already kept, preserving first-occurrence order. O(n^2) in the
# array's length, which is fine at manifest-row scale.
# ---------------------------------------------------------------------------
function(acpp_dedupe_json_array result_var arr)
  set(_out "[]")
  string(JSON _len LENGTH "${arr}")
  if(_len GREATER 0)
    math(EXPR _last "${_len} - 1")
    foreach(_i RANGE 0 ${_last})
      string(JSON _elem GET "${arr}" ${_i})
      set(_dup FALSE)
      string(JSON _out_len LENGTH "${_out}")
      if(_out_len GREATER 0)
        math(EXPR _out_last "${_out_len} - 1")
        foreach(_j RANGE 0 ${_out_last})
          string(JSON _existing GET "${_out}" ${_j})
          string(JSON _eq EQUAL "${_existing}" "${_elem}")
          if(_eq)
            set(_dup TRUE)
            break()
          endif()
        endforeach()
      endif()
      if(NOT _dup)
        string(JSON _out_len2 LENGTH "${_out}")
        string(JSON _out SET "${_out}" ${_out_len2} "${_elem}")
      endif()
    endforeach()
  endif()
  set(${result_var} "${_out}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Deploy manifest merge: concatenate each group's array. `dedupe` (an
# optional 5th argument, OFF unless given) additionally collapses a row
# that arrived identical (same src, dest, files and every other key) from
# more than one contributor - e.g. the SPIR-V bitcode row ocl and ze both
# carry. acpp_merge_unit never passes it (tiers of one unit are never
# expected to duplicate each other's rows - a duplicate there is much more
# likely a mistake worth seeing); acpp_merge_units passes it ON for the
# cross-UNIT case, where two vendors legitimately shipping the same row is
# normal, not a mistake.
# ---------------------------------------------------------------------------
function(acpp_merge_deploy result_var base overlay overlay_label)
  set(_dedupe OFF)
  if(ARGC GREATER 4)
    list(GET ARGN 0 _dedupe)
  endif()
  set(_result "${base}")
  foreach(_group internal llvm external-permissive external-nonpermissive app-config)
    string(JSON _base_arr ERROR_VARIABLE _berr GET "${_result}" "${_group}")
    string(JSON _over_arr ERROR_VARIABLE _oerr GET "${overlay}" "${_group}")
    if(NOT _oerr)
      if(_berr)
        # Group not yet in result, add it
        set(_new_arr "${_over_arr}")
      else()
        acpp_concat_json_arrays(_new_arr "${_base_arr}" "${_over_arr}")
      endif()
      if(_dedupe)
        acpp_dedupe_json_array(_new_arr "${_new_arr}")
      endif()
      string(JSON _result SET "${_result}" "${_group}" "${_new_arr}")
    endif()
  endforeach()
  set(${result_var} "${_result}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Application-config text merge: concatenate KEY=value lines, FATAL_ERROR on
# a duplicate key. No existing primitive above covers this shape - config
# merges JSON objects, deploy concatenates JSON arrays, but an app-config
# fragment is plain KEY=value text, and a duplicate key is an error at
# every level (across tiers within one unit, and across units in the final
# installed file) - unlike a deploy manifest's rows, which just
# concatenate.
#
# seen_keys_var names a list variable in the CALLER's scope that
# accumulates every key seen so far: acpp_merge_unit passes a fresh one per
# unit (so that unit's own tiers are checked against each other only);
# acpp_merge_all carries one across every unit (so the final file's
# cross-unit rule is the same check, just with a longer-lived list) - the
# same primitive proves both.
# ---------------------------------------------------------------------------
function(acpp_merge_app_text result_var seen_keys_var base addition label)
  string(REGEX REPLACE "\r\n" "\n" _norm "${addition}")
  # REGEX MATCHALL builds a proper CMake list (auto-escaping any literal
  # ";" inside a match), unlike a plain string(REPLACE "\n" ";" ...) +
  # foreach, which would misread an embedded semicolon (e.g. one in a
  # comment sentence) as its own list separator and silently split a
  # single line in two.
  string(REGEX MATCHALL "[^\n]+" _lines "${_norm}")
  set(_seen "${${seen_keys_var}}")
  foreach(_line ${_lines})
    string(STRIP "${_line}" _line)
    if(_line STREQUAL "" OR _line MATCHES "^#")
      continue()
    endif()
    string(REGEX REPLACE "=.*" "" _key "${_line}")
    list(FIND _seen "${_key}" _idx)
    if(NOT _idx EQUAL -1)
      message(FATAL_ERROR "${label}: key ${_key} appears twice in the application config")
    endif()
    list(APPEND _seen "${_key}")
  endforeach()
  set(${seen_keys_var} "${_seen}" PARENT_SCOPE)
  if("${base}" STREQUAL "")
    set(${result_var} "${addition}" PARENT_SCOPE)
  else()
    set(${result_var} "${base}\n${addition}" PARENT_SCOPE)
  endif()
endfunction()

# ---------------------------------------------------------------------------
# Merge one unit's fragments across the three tiers
# (config/common -> config/<platform>/common -> config/<platform>/<arch>).
# `kind` is `config` (<unit>.json), `deploy` (deploy/<unit>.json) or `app`
# (app/<unit>.cfg).
# ---------------------------------------------------------------------------
function(acpp_merge_unit kind platform arch unit out_var)
  if("${kind}" STREQUAL "config")
    set(_rel "${unit}.json")
  elseif("${kind}" STREQUAL "deploy")
    set(_rel "deploy/${unit}.json")
  elseif("${kind}" STREQUAL "app")
    set(_rel "app/${unit}.cfg")
  else()
    message(FATAL_ERROR "acpp_merge_unit: kind must be config, deploy or app, not '${kind}'.")
  endif()

  if("${kind}" STREQUAL "app")
    set(_merged "")
  else()
    set(_merged "{}")
  endif()
  set(_seen_keys "")

  foreach(_tier
      "config/common/${_rel}|common/${_rel}"
      "config/${platform}/common/${_rel}|${platform}/common/${_rel}"
      "config/${platform}/${arch}/${_rel}|${platform}/${arch}/${_rel}")
    string(REGEX REPLACE "\\|.*" "" _path "${_tier}")
    string(REGEX REPLACE ".*\\|" "" _label "${_tier}")
    if(EXISTS "${_ACPP_MERGE_REPO_ROOT}/${_path}")
      file(READ "${_ACPP_MERGE_REPO_ROOT}/${_path}" _frag_text)
      if("${kind}" STREQUAL "config")
        acpp_merge_json_objects(_merged "${_merged}" "${_frag_text}" "${_label}")
      elseif("${kind}" STREQUAL "deploy")
        acpp_merge_deploy(_merged "${_merged}" "${_frag_text}" "${_label}")
      else()
        acpp_merge_app_text(_merged _seen_keys "${_merged}" "${_frag_text}" "${_label}")
      endif()
    endif()
  endforeach()

  set(${out_var} "${_merged}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Merge an explicit list of units of one kind into the final single file
# for one platform/arch: config objects merged key-wise (a duplicate key is
# an error across units too, not just within one unit's own tiers), deploy
# groups concatenated per group across every unit with identical rows
# collapsed (e.g. the SPIR-V bitcode row ocl and ze both carry - see
# acpp_merge_deploy's dedupe argument), app lines concatenated (a duplicate
# key is an error across units too, same rule as within one unit's own
# tiers).
#
# Used both by acpp_merge_all (below, whose unit list is every unit found
# on disk) and by acpp_generate_installed_configs (cmake/acpp-installed-
# configs.cmake), whose unit list is whatever the build actually enables.
# ---------------------------------------------------------------------------
function(acpp_merge_units kind platform arch units out_var)
  if("${kind}" STREQUAL "app")
    set(_merged "")
  else()
    set(_merged "{}")
  endif()
  set(_seen_keys "")

  foreach(_unit ${units})
    acpp_merge_unit("${kind}" "${platform}" "${arch}" "${_unit}" _unit_text)
    if("${kind}" STREQUAL "config")
      acpp_merge_json_objects(_merged "${_merged}" "${_unit_text}" "${_unit}")
    elseif("${kind}" STREQUAL "deploy")
      acpp_merge_deploy(_merged "${_merged}" "${_unit_text}" "${_unit}" ON)
    else()
      acpp_merge_app_text(_merged _seen_keys "${_merged}" "${_unit_text}" "${_unit}")
    endif()
  endforeach()

  set(${out_var} "${_merged}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Merge every unit of one kind into the final single file for one
# platform/arch, where "every unit" is discovered rather than given: the
# union of whatever <unit>.json / deploy/<unit>.json / app/<unit>.cfg files
# exist across the three tiers, since a unit can be introduced at any tier
# (a vendor with no common file at all, an arch-only addition like SVML).
# The actual merge is acpp_merge_units, above; this only computes the list.
# ---------------------------------------------------------------------------
function(acpp_merge_all kind platform arch out_var)
  if("${kind}" STREQUAL "config")
    set(_subdir "")
    set(_ext "json")
  elseif("${kind}" STREQUAL "deploy")
    set(_subdir "deploy/")
    set(_ext "json")
  elseif("${kind}" STREQUAL "app")
    set(_subdir "app/")
    set(_ext "cfg")
  else()
    message(FATAL_ERROR "acpp_merge_all: kind must be config, deploy or app, not '${kind}'.")
  endif()

  set(_units "")
  foreach(_dir
      "config/common/${_subdir}"
      "config/${platform}/common/${_subdir}"
      "config/${platform}/${arch}/${_subdir}")
    file(GLOB _files "${_ACPP_MERGE_REPO_ROOT}/${_dir}*.${_ext}")
    foreach(_f ${_files})
      get_filename_component(_stem "${_f}" NAME_WE)
      list(APPEND _units "${_stem}")
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES _units)

  acpp_merge_units("${kind}" "${platform}" "${arch}" "${_units}" _merged)
  set(${out_var} "${_merged}" PARENT_SCOPE)
endfunction()
