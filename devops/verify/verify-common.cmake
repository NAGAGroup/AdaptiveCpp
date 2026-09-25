cmake_minimum_required(VERSION 3.19)

# The merge harness and the tier proof.
#
# For every golden file, collects the fragments at the three tiers
# (config/common/, config/<platform>/common/, config/<platform>/<arch>/),
# merges them via the shared engine in cmake/acpp-config-merge.cmake (the
# same one the build itself uses), and asserts JSON equality with the
# golden. Also asserts the cmake tier rule.
#
# Run with cmake -P:
#   cmake -P devops/verify/verify-common.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-config-merge.cmake)

set(_platforms_archs
  linux    x86_64
  linux    aarch64
  windows  x86_64
  windows  aarch64
  macos    arm64)

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

    # Determine if this is a deploy manifest (path starts with deploy/) and,
    # from that, the kind/unit pair acpp_merge_unit takes.
    string(FIND "${_R}" "deploy/" _is_deploy)
    if(_is_deploy EQUAL 0)
      set(_kind "deploy")
      string(REGEX REPLACE "^deploy/(.*)\\.json$" "\\1" _unit "${_R}")
    else()
      set(_kind "config")
      string(REGEX REPLACE "\\.json$" "" _unit "${_R}")
    endif()

    # Count/track which tier fragments exist, for the zero-fragment and
    # stray-fragment checks below - the merge itself is acpp_merge_unit's
    # job now (cmake/acpp-config-merge.cmake), which walks the identical
    # three tier paths on its own.
    set(_nfrags 0)
    foreach(_path
        "config/common/${_R}"
        "config/${_platform}/common/${_R}"
        "config/${_platform}/${_arch}/${_R}")
      if(EXISTS "${ACPP_REPO_ROOT}/${_path}")
        math(EXPR _nfrags "${_nfrags} + 1")
        list(APPEND _contributed_fragments "${_path}")
      endif()
    endforeach()
    if(_nfrags EQUAL 0)
      message(FATAL_ERROR
        "${_platform}/${_arch}/${_R}: no fragments found for this golden")
    endif()

    acpp_merge_unit("${_kind}" "${_platform}" "${_arch}" "${_unit}" _merged)

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
