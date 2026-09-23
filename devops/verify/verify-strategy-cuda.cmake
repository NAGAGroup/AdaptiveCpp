# The strategy case: CUDA on linux/x86_64, run with cmake -P:
#   cmake -P devops/verify/verify-strategy-cuda.cmake
#
# D6/D7's claim end to end: a manifest's copy rows are the same static
# {{ }} template text regardless of ACPP_DEPLOYMENT_STRATEGY - only the
# driver-resolved config entries and the app-config rows' baked @VAR@
# values move. This harness proves it for CUDA:
#
#   (a) the deploy manifest's copy rows carry no @VAR@ token at all - they
#       are pure driver-template text, identical across every strategy by
#       construction, since cmake's configure_file never touches them;
#   (b) the app-config row for ACPP_CUDA_LIBDEVICE_DIR is the one thing
#       that flips - the absolute composition under `default`, the literal
#       $ACPP_RUNTIME_ROOT template under `managed`/`full`;
#   (c) a conda-shaped case (ACPP_CUDA_SUBDIR set to "") demonstrates that
#       naive {{ }} substitution of that template produces a doubled slash
#       - documented here as an obligation for the deploy engine, which
#       resolves {{ }} tokens at drive time and must normalize the path it
#       produces, not something cmake's options layer should special-case
#       (cuda-subdir stays a deferred template at configure time; cmake
#       never concatenates its actual value with anything).
#
# Runs the options files in three separate `cmake -P` child processes
# (verify-strategy-cuda-inner.cmake) because include_guard(GLOBAL) forbids
# including cuda.cmake twice in one process, and three strategies need
# three runs.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(_inner "${CMAKE_CURRENT_LIST_DIR}/verify-strategy-cuda-inner.cmake")

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# (a) The manifest's copy rows carry no @VAR@ token; only app-config does.
# ---------------------------------------------------------------------------

file(READ "${ACPP_REPO_ROOT}/config/linux/common/deploy/cuda.json" _manifest_text)
string(JSON _app_config GET "${_manifest_text}" "app-config")
string(JSON _app_config_len LENGTH "${_app_config}")
if(_app_config_len EQUAL 0)
  message(FATAL_ERROR "cuda.json manifest: app-config is empty, expected the libdevice row")
endif()
if(NOT "${_app_config}" MATCHES "@ACPP_APP_CUDA_LIBDEVICE_SUBDIR@")
  message(FATAL_ERROR "cuda.json manifest: app-config does not bake @ACPP_APP_CUDA_LIBDEVICE_SUBDIR@")
endif()

foreach(_group internal external-nonpermissive)
  string(JSON _rows GET "${_manifest_text}" "${_group}")
  if("${_rows}" MATCHES "@ACPP_")
    message(FATAL_ERROR
      "cuda.json manifest: '${_group}' copy rows reference an @ACPP_...@ "
      "token - copy rows must be pure {{ }} driver template text, "
      "identical across every strategy")
  endif()
endforeach()
message(STATUS "cuda.json manifest: copy rows carry no @VAR@ token, only app-config does")

# ---------------------------------------------------------------------------
# (b) The app-config row's value flips with strategy; the copy rows (being
#     the same static file for every strategy) are byte-identical by
#     construction - the file above is read once, and every strategy below
#     reads that identical on-disk text at drive time.
# ---------------------------------------------------------------------------

function(run_strategy strategy out_var)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -D "ACPP_DEPLOYMENT_STRATEGY=${strategy}" -P "${_inner}"
    OUTPUT_VARIABLE _out ERROR_VARIABLE _out2 RESULT_VARIABLE _res)
  if(NOT _res EQUAL 0)
    message(FATAL_ERROR "strategy '${strategy}' inner run failed:\n${_out}\n${_out2}")
  endif()
  set(${out_var} "${_out}${_out2}" PARENT_SCOPE)
endfunction()

function(extract_result blob key out_var)
  string(REGEX MATCH "RESULT:${key}=([^\r\n]*)" _m "${blob}")
  if(NOT _m)
    message(FATAL_ERROR "could not find RESULT:${key}= in child output:\n${blob}")
  endif()
  set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()

run_strategy("default" _default_out)
extract_result("${_default_out}" "ACPP_APP_CUDA_LIBDEVICE_SUBDIR" _default_libdevice)
expect_eq(_default_libdevice "{{ cuda-install-root }}/{{ cuda-libdevice-subdir }}")

run_strategy("managed" _managed_out)
extract_result("${_managed_out}" "ACPP_APP_CUDA_LIBDEVICE_SUBDIR" _managed_libdevice)
expect_eq(_managed_libdevice "\$ACPP_RUNTIME_ROOT/{{ cuda-subdir }}/{{ cuda-libdevice-subdir }}")

run_strategy("full" _full_out)
extract_result("${_full_out}" "ACPP_APP_CUDA_LIBDEVICE_SUBDIR" _full_libdevice)
expect_eq(_full_libdevice "\$ACPP_RUNTIME_ROOT/{{ cuda-subdir }}/{{ cuda-libdevice-subdir }}")

if(NOT "${_managed_libdevice}" STREQUAL "${_full_libdevice}")
  message(FATAL_ERROR "managed and full disagree on the app-config row; they must not")
endif()

message(STATUS "cuda: app-config row flips default -> managed/full, copy rows untouched")

# ---------------------------------------------------------------------------
# (c) Conda-shaped case: ACPP_CUDA_SUBDIR set to "". The cmake-level
#     template itself does not change (cuda-subdir stays a deferred {{ }}
#     token, never concatenated by cmake with its actual value); a naive
#     substitution of that token - the deploy engine's own job at drive
#     time - is simulated here only to document what it must guard against.
# ---------------------------------------------------------------------------

execute_process(
  COMMAND ${CMAKE_COMMAND} -D "ACPP_DEPLOYMENT_STRATEGY=managed" -D "ACPP_CUDA_SUBDIR=" -P "${_inner}"
  OUTPUT_VARIABLE _conda_out ERROR_VARIABLE _conda_out2 RESULT_VARIABLE _conda_res)
if(NOT _conda_res EQUAL 0)
  message(FATAL_ERROR "conda-shaped run failed:\n${_conda_out}\n${_conda_out2}")
endif()
set(_conda_out "${_conda_out}${_conda_out2}")

extract_result("${_conda_out}" "ACPP_CUDA_SUBDIR" _conda_subdir)
expect_eq(_conda_subdir "")
extract_result("${_conda_out}" "ACPP_APP_CUDA_LIBDEVICE_SUBDIR" _conda_libdevice)
# Unchanged from the managed case above: cmake never substitutes {{ }}
# tokens, so an empty ACPP_CUDA_SUBDIR is invisible at this layer.
expect_eq(_conda_libdevice "\$ACPP_RUNTIME_ROOT/{{ cuda-subdir }}/{{ cuda-libdevice-subdir }}")

# Simulate the deploy engine's own {{ }} resolution to show what it must
# normalize: substituting the empty subdir leaves two adjacent "/" where
# the manifest's own text supplied one on each side of the token.
string(REPLACE "{{ cuda-subdir }}" "${_conda_subdir}" _naive "${_conda_libdevice}")
string(REPLACE "{{ cuda-libdevice-subdir }}" "nvvm/libdevice" _naive "${_naive}")
expect_eq(_naive "\$ACPP_RUNTIME_ROOT//nvvm/libdevice")
message(STATUS
  "cuda (conda-shaped, ACPP_CUDA_SUBDIR=\"\"): naive {{ }} substitution "
  "gives '${_naive}' - the doubled slash is the deploy engine's own "
  "obligation to normalize when it resolves {{ }} tokens at drive time; "
  "cmake's options layer deliberately never special-cases it, because "
  "cuda-subdir is never concatenated with anything at configure time.")

message(STATUS "verify-strategy-cuda: all checks passed")
