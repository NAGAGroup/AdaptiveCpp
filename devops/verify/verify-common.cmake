cmake_minimum_required(VERSION 3.19)

# The merge harness and the tier proof.
#
# For every golden file, collects the fragments at the three tiers
# (config/common/, config/<platform>/common/, config/<platform>/<arch>/),
# merges them per the model's merge section, and asserts JSON equality
# with the golden. Also
# asserts the cmake tier rule.
#
# Run with cmake -P:
#   cmake -P devops/verify/verify-common.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(_platforms_archs
  linux    x86_64
  linux    aarch64
  windows  x86_64
  windows  aarch64
  macos    arm64)

# ---------------------------------------------------------------------------
# Helper: merge two JSON objects. FATAL_ERROR on duplicate key.
# ---------------------------------------------------------------------------
function(_merge_json_objects result_var base overlay overlay_label)
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
# Helper: merge two JSON arrays by concatenation.
# ---------------------------------------------------------------------------
function(_concat_json_arrays result_var base addition)
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
# Helper: merge deploy manifests (concatenate each group's array).
# ---------------------------------------------------------------------------
function(_merge_deploy result_var base overlay overlay_label)
  set(_result "${base}")
  foreach(_group internal llvm external-permissive external-nonpermissive app-config)
    string(JSON _base_arr ERROR_VARIABLE _berr GET "${_result}" "${_group}")
    string(JSON _over_arr ERROR_VARIABLE _oerr GET "${overlay}" "${_group}")
    if(NOT _oerr)
      if(_berr)
        # Group not yet in result, add it
        string(JSON _result SET "${_result}" "${_group}" "${_over_arr}")
      else()
        _concat_json_arrays(_merged "${_base_arr}" "${_over_arr}")
        string(JSON _result SET "${_result}" "${_group}" "${_merged}")
      endif()
    endif()
  endforeach()
  set(${result_var} "${_result}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Track every fragment file that contributes to a golden.
# ---------------------------------------------------------------------------
set(_contributed_fragments "")

# ---------------------------------------------------------------------------
# (a-c) For each platform/arch, merge fragments and compare to golden.
# ---------------------------------------------------------------------------
list(LENGTH _platforms_archs _pa_len)
math(EXPR _pa_last "${_pa_len} - 2")
foreach(_i RANGE 0 ${_pa_last} 2)
  math(EXPR _j "${_i} + 1")
  list(GET _platforms_archs ${_i} _platform)
  list(GET _platforms_archs ${_j} _arch)

  file(GLOB_RECURSE _goldens
    RELATIVE "${ACPP_REPO_ROOT}/devops/verify/golden/${_platform}/${_arch}"
    "${ACPP_REPO_ROOT}/devops/verify/golden/${_platform}/${_arch}/*.json")

  foreach(_R ${_goldens})
    file(READ "${ACPP_REPO_ROOT}/devops/verify/golden/${_platform}/${_arch}/${_R}" _golden_text)

    # Determine if this is a deploy manifest (path starts with deploy/)
    string(FIND "${_R}" "deploy/" _is_deploy)

    # Collect fragments in tier order
    set(_fragments "")
    set(_fragment_labels "")
    foreach(_tier
        "config/common/${_R}|common"
        "config/${_platform}/common/${_R}|${_platform}/common"
        "config/${_platform}/${_arch}/${_R}|${_platform}/${_arch}")
      string(REGEX REPLACE "\\|.*" "" _path "${_tier}")
      string(REGEX REPLACE ".*\\|" "" _label "${_tier}")
      if(EXISTS "${ACPP_REPO_ROOT}/${_path}")
        list(APPEND _fragments "${ACPP_REPO_ROOT}/${_path}")
        list(APPEND _fragment_labels "${_label}")
        list(APPEND _contributed_fragments "${_path}")
      endif()
    endforeach()

    list(LENGTH _fragments _nfrags)
    if(_nfrags EQUAL 0)
      message(FATAL_ERROR
        "${_platform}/${_arch}/${_R}: no fragments found for this golden")
    endif()

    # Merge
    if(_is_deploy EQUAL 0)
      # Deploy manifest: concatenate arrays
      set(_merged "{}")
      foreach(_frag _flabel IN ZIP_LISTS _fragments _fragment_labels)
        file(READ "${_frag}" _frag_text)
        _merge_deploy(_merged "${_merged}" "${_frag_text}" "${_flabel}/${_R}")
      endforeach()
    else()
      # Configuration file: union of members
      set(_merged "{}")
      foreach(_frag _flabel IN ZIP_LISTS _fragments _fragment_labels)
        file(READ "${_frag}" _frag_text)
        _merge_json_objects(_merged "${_merged}" "${_frag_text}" "${_flabel}/${_R}")
      endforeach()
    endif()

    # Compare semantically; a malformed fragment or golden fails loudly.
    string(JSON _equal EQUAL "${_golden_text}" "${_merged}")
    if(NOT _equal)
      message(FATAL_ERROR
        "${_platform}/${_arch}/${_R}: merge does not equal golden\n"
        "GOLDEN:\n${_golden_text}\n\nMERGED:\n${_merged}")
    endif()

    message(STATUS "${_platform}/${_arch}/${_R}: merge equals golden (${_nfrags} fragments)")
  endforeach()
endforeach()

# ---------------------------------------------------------------------------
# (d) Assert no stray fragment.
# ---------------------------------------------------------------------------
file(GLOB_RECURSE _all_config_files
  RELATIVE "${ACPP_REPO_ROOT}"
  "${ACPP_REPO_ROOT}/config/*.json")
foreach(_cf ${_all_config_files})
  list(FIND _contributed_fragments "${_cf}" _idx)
  if(_idx EQUAL -1)
    message(FATAL_ERROR "Stray fragment: ${_cf} is not reached by any golden")
  endif()
endforeach()
message(STATUS "common: no stray fragments")

# ---------------------------------------------------------------------------
# (e) The cmake tier rule.
# ---------------------------------------------------------------------------
foreach(_i RANGE 0 ${_pa_last} 2)
  math(EXPR _j "${_i} + 1")
  list(GET _platforms_archs ${_i} _platform)
  list(GET _platforms_archs ${_j} _arch)

  file(GLOB _arch_cmake_files
    "${ACPP_REPO_ROOT}/cmake/options/${_platform}/${_arch}/*.cmake")

  foreach(_f ${_arch_cmake_files})
    get_filename_component(_basename "${_f}" NAME)
    get_filename_component(_stem "${_f}" NAME_WE)
    file(READ "${_f}" _content)
    # Strip comments and blank lines
    string(REGEX REPLACE "#[^\n]*" "" _stripped "${_content}")
    string(REGEX REPLACE "\n[ \t]*\n" "\n" _stripped "${_stripped}")
    string(STRIP "${_stripped}" _stripped)

    set(_expected_include
      "include(\${CMAKE_CURRENT_LIST_DIR}/../common/${_stem}.cmake)")

    if(NOT "${_stem}" STREQUAL "core")
      # Non-core: must be exactly include_guard(GLOBAL) and one include of
      # the platform common file for this stem, nothing else.
      string(REGEX REPLACE "include_guard\\(GLOBAL\\)" "" _rest "${_stripped}")
      string(STRIP "${_rest}" _rest)
      # The remaining text must be exactly the expected include line.
      if(NOT "${_rest}" STREQUAL "${_expected_include}")
        message(FATAL_ERROR
          "${_platform}/${_arch}/${_basename}: non-core arch file must be "
          "include_guard(GLOBAL) and include(.../${_stem}.cmake), got:\n${_rest}")
      endif()
    else()
      # Core: include_guard(GLOBAL) must come first, then the include of
      # ../common/core.cmake; declarations may follow (the arch delta).
      string(REGEX REPLACE "include_guard\\(GLOBAL\\)" "" _rest "${_stripped}")
      string(STRIP "${_rest}" _rest)
      string(FIND "${_rest}" "${_expected_include}" _pos)
      if(NOT _pos EQUAL 0)
        message(FATAL_ERROR
          "${_platform}/${_arch}/core.cmake: first line after include_guard "
          "must be include(.../common/core.cmake)")
      endif()
    endif()
  endforeach()

  # Platform common core must include ../../common/core.cmake
  set(_pc "${ACPP_REPO_ROOT}/cmake/options/${_platform}/common/core.cmake")
  if(EXISTS "${_pc}")
    file(READ "${_pc}" _pc_content)
    string(FIND "${_pc_content}" "../../common/core.cmake" _found)
    if(_found EQUAL -1)
      message(FATAL_ERROR
        "${_platform}/common/core.cmake does not include ../../common/core.cmake")
    endif()
  endif()

  message(STATUS "${_platform}/${_arch}: tier rule holds")
endforeach()

# ---------------------------------------------------------------------------
# (f) All done.
# ---------------------------------------------------------------------------
message(STATUS "common: all merges equal their goldens, tier rule holds")
