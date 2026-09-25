# Generate the installed toolchain config, deploy manifest and application
# config for one platform/arch, from the units currently enabled - the
# generation half of root wiring (a later step of Commit 3 wires this into
# a real install() rule; this file only knows how to produce the three
# files given a repo, an output directory and the units in scope).
#
# The caller has already included the relevant options files (core.cmake
# plus whichever vendor .cmake files the units in UNITS need), so every
# @VAR@ the merged templates reference - and LLVM_ADAPTIVECPP_LINK_INTO_
# TOOLS, ACPP_DEPLOYMENT_STRATEGY, ACPP_DISCOVERED_HIP_HIPRTC where
# relevant - is already set in the calling scope. This file never guesses
# a default for any of them itself.

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/acpp-config-merge.cmake")

# ---------------------------------------------------------------------------
# Collect every @VAR@ token appearing in a piece of template text.
# ---------------------------------------------------------------------------
function(_acpp_collect_at_vars text out_var)
  string(REGEX MATCHALL "@[A-Za-z0-9_]+@" _matches "${text}")
  set(_vars "")
  foreach(_m ${_matches})
    string(REGEX REPLACE "^@|@$" "" _v "${_m}")
    list(APPEND _vars "${_v}")
  endforeach()
  list(REMOVE_DUPLICATES _vars)
  set(${out_var} "${_vars}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Filter one deploy group's rows by build-mode and unless, then strip both
# keys from the rows that are kept.
#
# A row with no build-mode key applies in every build mode; one with a
# build-mode key applies only when it matches whichever mode
# LLVM_ADAPTIVECPP_LINK_INTO_TOOLS selects ("toolchain" when ON, "plugin"
# when OFF).
#
# A row with no unless key always applies. "unless": "hiprtc-link" is the
# one condition the model currently defines: the clang++/resource-dir rows
# hip's manifest ships for the generic clangJitLink path are needed only
# when the build did NOT link hipRTC's own alternative - so the row is
# dropped when ACPP_DISCOVERED_HIP_HIPRTC is ON. See doc/configuration-
# model.md ("Clang and its headers are hip's rows, not core's") and
# cmake/discovery/hip.cmake (where ACPP_DISCOVERED_HIP_HIPRTC is set from
# whether libhiprtc.so exists next to the discovered HIP install).
# ---------------------------------------------------------------------------
function(_acpp_filter_deploy_group result_var group_arr)
  set(_out "[]")
  string(JSON _len LENGTH "${group_arr}")
  if(_len GREATER 0)
    math(EXPR _last "${_len} - 1")
    foreach(_i RANGE 0 ${_last})
      string(JSON _row GET "${group_arr}" ${_i})
      set(_keep TRUE)

      string(JSON _bm ERROR_VARIABLE _bmerr GET "${_row}" "build-mode")
      if(NOT _bmerr)
        if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
          set(_this_mode "toolchain")
        else()
          set(_this_mode "plugin")
        endif()
        if(NOT "${_bm}" STREQUAL "${_this_mode}")
          set(_keep FALSE)
        endif()
      endif()

      if(_keep)
        string(JSON _un ERROR_VARIABLE _unerr GET "${_row}" "unless")
        if(NOT _unerr)
          if("${_un}" STREQUAL "hiprtc-link")
            if(ACPP_DISCOVERED_HIP_HIPRTC)
              set(_keep FALSE)
            endif()
          else()
            message(FATAL_ERROR
              "acpp_generate_installed_configs: unknown 'unless' condition '${_un}'")
          endif()
        endif()
      endif()

      if(_keep)
        string(JSON _has_bm ERROR_VARIABLE _bmerr2 GET "${_row}" "build-mode")
        if(NOT _bmerr2)
          string(JSON _row REMOVE "${_row}" "build-mode")
        endif()
        string(JSON _has_un ERROR_VARIABLE _unerr2 GET "${_row}" "unless")
        if(NOT _unerr2)
          string(JSON _row REMOVE "${_row}" "unless")
        endif()
        string(JSON _out_len LENGTH "${_out}")
        string(JSON _out SET "${_out}" ${_out_len} "${_row}")
      endif()
    endforeach()
  endif()
  set(${result_var} "${_out}" PARENT_SCOPE)
endfunction()

function(_acpp_filter_deploy_json result_var deploy_json)
  set(_result "${deploy_json}")
  foreach(_group internal llvm external-permissive external-nonpermissive app-config)
    string(JSON _arr ERROR_VARIABLE _err GET "${_result}" "${_group}")
    if(NOT _err)
      _acpp_filter_deploy_group(_filtered "${_arr}")
      string(JSON _result SET "${_result}" "${_group}" "${_filtered}")
    endif()
  endforeach()
  set(${result_var} "${_result}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# acpp_generate_installed_configs(PLATFORM <p> ARCH <a> UNITS <list>
#                                  OUT_DIR <dir>)
#
# core and omp are always merged in, alongside whichever vendor units this
# build enables (UNITS). Writes OUT_DIR/acpp-toolchain.json and
# OUT_DIR/acpp-app.cfg always, and OUT_DIR/acpp-deploy.json only when
# ACPP_DEPLOYMENT_STRATEGY is not managed (managed ships nothing, so there
# is nothing for a manifest to say).
# ---------------------------------------------------------------------------
function(acpp_generate_installed_configs)
  cmake_parse_arguments(ACPP_GEN "" "PLATFORM;ARCH;OUT_DIR" "UNITS" ${ARGN})
  if(NOT ACPP_GEN_PLATFORM OR NOT ACPP_GEN_ARCH OR NOT ACPP_GEN_OUT_DIR)
    message(FATAL_ERROR
      "acpp_generate_installed_configs: PLATFORM, ARCH and OUT_DIR are required")
  endif()

  # ACPP_PLUGIN_PATH is genuinely undefined in toolchain mode - not merely
  # empty - by existing, deliberate design (see linux/common/core.cmake's
  # compiler-plugin section: "when AdaptiveCpp is linked into the LLVM
  # tools there is no plugin file... the driver emits no plugin flags";
  # verify-core.cmake and its macOS/Windows counterparts assert exactly
  # this with expect_unset(ACPP_PLUGIN_PATH)). The "plugin-path" config key
  # still exists in every build mode's schema, though, so its
  # @ACPP_PLUGIN_PATH@ reference resolving to empty there is correct, not
  # a forgotten variable. Default it function-locally, which never escapes
  # to the caller's scope (no PARENT_SCOPE) and so changes nothing any
  # other harness or the rest of the build sees - just what (c) below
  # finds when it looks.
  if(NOT DEFINED ACPP_PLUGIN_PATH)
    set(ACPP_PLUGIN_PATH "")
  endif()

  # (a) Merge each kind over the given units.
  set(_units core omp ${ACPP_GEN_UNITS})
  list(REMOVE_DUPLICATES _units)

  acpp_merge_units("config" "${ACPP_GEN_PLATFORM}" "${ACPP_GEN_ARCH}" "${_units}" _config_json)
  acpp_merge_units("deploy" "${ACPP_GEN_PLATFORM}" "${ACPP_GEN_ARCH}" "${_units}" _deploy_json)
  acpp_merge_units("app"    "${ACPP_GEN_PLATFORM}" "${ACPP_GEN_ARCH}" "${_units}" _app_text)

  # (b) Filter the deploy manifest by build-mode/unless, stripping both keys
  # from whatever rows are kept.
  _acpp_filter_deploy_json(_deploy_json "${_deploy_json}")

  # (c) Every @VAR@ the merged config/app templates reference must already
  # be defined - configure_file would otherwise silently write empty,
  # which is indistinguishable from a legitimately empty value once
  # written, and far harder to diagnose than failing here, now.
  _acpp_collect_at_vars("${_config_json}" _config_vars)
  _acpp_collect_at_vars("${_app_text}" _app_vars)
  set(_all_vars ${_config_vars} ${_app_vars})
  list(REMOVE_DUPLICATES _all_vars)
  set(_undefined "")
  foreach(_v ${_all_vars})
    if(NOT DEFINED ${_v})
      list(APPEND _undefined "${_v}")
    endif()
  endforeach()
  if(_undefined)
    message(FATAL_ERROR
      "acpp_generate_installed_configs: @VAR@ referenced but not defined: ${_undefined}")
  endif()

  # (d) configure_file(@ONLY) the merged templates into OUT_DIR.
  # configure_file needs a real input file, not a string in a variable, so
  # the merged text is written to a throwaway subdirectory of OUT_DIR
  # first.
  set(_tmp_dir "${ACPP_GEN_OUT_DIR}/.acpp-merge-templates")
  file(MAKE_DIRECTORY "${_tmp_dir}")
  file(MAKE_DIRECTORY "${ACPP_GEN_OUT_DIR}")

  file(WRITE "${_tmp_dir}/acpp-toolchain.json.in" "${_config_json}")
  configure_file("${_tmp_dir}/acpp-toolchain.json.in" "${ACPP_GEN_OUT_DIR}/acpp-toolchain.json" @ONLY)

  file(WRITE "${_tmp_dir}/acpp-app.cfg.in" "${_app_text}")
  configure_file("${_tmp_dir}/acpp-app.cfg.in" "${ACPP_GEN_OUT_DIR}/acpp-app.cfg" @ONLY)

  if(NOT "${ACPP_DEPLOYMENT_STRATEGY}" STREQUAL "managed")
    file(WRITE "${_tmp_dir}/acpp-deploy.json.in" "${_deploy_json}")
    configure_file("${_tmp_dir}/acpp-deploy.json.in" "${ACPP_GEN_OUT_DIR}/acpp-deploy.json" @ONLY)
  endif()

  # (e) Every {{ key }} left in the generated toolchain config's own values,
  # and in the manifest if one was generated, must be acpp-root,
  # acpp-runtime-root, or a key the generated toolchain config itself
  # defines - nothing else is ever a valid {{ }} name, and an unresolved
  # one would silently reach the driver or the deploy step as literal text.
  file(READ "${ACPP_GEN_OUT_DIR}/acpp-toolchain.json" _generated_config)
  set(_manifest_text "")
  if(EXISTS "${ACPP_GEN_OUT_DIR}/acpp-deploy.json")
    file(READ "${ACPP_GEN_OUT_DIR}/acpp-deploy.json" _manifest_text)
  endif()

  set(_known_keys "acpp-root" "acpp-runtime-root")
  string(JSON _nkeys LENGTH "${_generated_config}")
  if(_nkeys GREATER 0)
    math(EXPR _nlast "${_nkeys} - 1")
    foreach(_i RANGE 0 ${_nlast})
      string(JSON _k MEMBER "${_generated_config}" ${_i})
      list(APPEND _known_keys "${_k}")
    endforeach()
  endif()

  string(REGEX MATCHALL "{{ *[A-Za-z0-9-]+ *}}" _tokens "${_generated_config}${_manifest_text}")
  set(_unknown_keys "")
  foreach(_t ${_tokens})
    string(REGEX REPLACE "{{|}}" "" _key "${_t}")
    string(STRIP "${_key}" _key)
    list(FIND _known_keys "${_key}" _idx)
    if(_idx EQUAL -1)
      list(APPEND _unknown_keys "${_key}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _unknown_keys)
  if(_unknown_keys)
    message(FATAL_ERROR
      "acpp_generate_installed_configs: unresolved {{ }} key(s): ${_unknown_keys}")
  endif()

  # (f) The generated app config is plain KEY=value text: no {{ }} (an
  # app-config fragment never had one - its values are @VAR@ only) and no
  # @ left over (every @VAR@ it referenced was resolved by configure_file
  # above, or this function would already have FATAL_ERRORed at (c)).
  file(READ "${ACPP_GEN_OUT_DIR}/acpp-app.cfg" _generated_app)
  if("${_generated_app}" MATCHES "{{")
    message(FATAL_ERROR
      "acpp_generate_installed_configs: generated app config still contains a {{ }} token")
  endif()
  if("${_generated_app}" MATCHES "@")
    message(FATAL_ERROR
      "acpp_generate_installed_configs: generated app config still contains an unresolved @ token")
  endif()
endfunction()
