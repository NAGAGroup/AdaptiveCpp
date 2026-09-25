# The strategy case: CUDA on linux/x86_64, run with cmake -P:
#   cmake -P devops/verify/verify-strategy-cuda.cmake
#
# CUDA is nonpermissive, so it is the one vendor that exercises every part
# of the per-vendor rule at once: not shipped under managed, shipped (and
# gated) under full. This harness proves it end to end:
#
#   (a) the deploy manifest's copy rows carry no @VAR@ token at all - they
#       are pure driver-template text, identical across every strategy by
#       construction, since cmake's configure_file never touches them;
#   (b) the app-config row for ACPP_CUDA_LIBDEVICE_DIR is the one thing
#       that flips - the discovered absolute path under managed (not
#       shipped), a concrete $ACPP_RT_LIB_DIR-relative path under full
#       (shipped, gate on);
#   (c) full with the gate off is a configure error (the EULA gate
#       acpp_declare_vendor's category check exists for);
#   (d) a conda-shaped case (ACPP_CUDA_SUBDIR set to "") under full proves
#       cmake's own relative-path computation normalizes the empty subdir
#       itself, with no doubled slash - unlike the old deferred {{ }}
#       template model, there is no separate "deploy engine's obligation"
#       left here to document: acpp_relative_from_rt_libdir/
#       acpp_join_relative do this once, at configure time.
#
# Runs the options files in separate `cmake -P` child processes
# (verify-strategy-cuda-inner.cmake) because include_guard(GLOBAL) forbids
# including cuda.cmake twice in one process, and FATAL_ERROR (case (c))
# has no in-process way to be caught at all - it always terminates
# whichever process hits it.

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
if(NOT "${_app_config}" MATCHES "@ACPP_APP_CUDA_LIBDEVICE_DIR@")
  message(FATAL_ERROR "cuda.json manifest: app-config does not bake @ACPP_APP_CUDA_LIBDEVICE_DIR@")
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

# managed: not shipped, so the app-config row is the discovered absolute
# path - the same location the driver's own toolchain-side value names.
run_strategy("managed" _managed_out)
extract_result("${_managed_out}" "ACPP_APP_CUDA_LIBDEVICE_DIR" _managed_libdevice)
expect_eq(_managed_libdevice "/usr/local/cuda-12.9/nvvm/libdevice")

# full: shipped, so the app-config row is a concrete path from the runtime
# library's own install directory ("lib") to the cuda subdir's default
# ("lib/hipSYCL/ext/cuda", relative from "lib" is "hipSYCL/ext/cuda") plus
# the libdevice subdir fact - fully resolved, no {{ }} left for anything
# to resolve later. CUDA is nonpermissive, so shipping it under full needs
# the gate on.
function(run_strategy_gated strategy gate out_var)
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -D "ACPP_DEPLOYMENT_STRATEGY=${strategy}"
      -D "ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN=${gate}"
      -P "${_inner}"
    OUTPUT_VARIABLE _out ERROR_VARIABLE _out2 RESULT_VARIABLE _res)
  if(NOT _res EQUAL 0)
    message(FATAL_ERROR "strategy '${strategy}' (gate ${gate}) inner run failed:\n${_out}\n${_out2}")
  endif()
  set(${out_var} "${_out}${_out2}" PARENT_SCOPE)
endfunction()

run_strategy_gated("full" "ON" _full_out)
extract_result("${_full_out}" "ACPP_APP_CUDA_LIBDEVICE_DIR" _full_libdevice)
expect_eq(_full_libdevice "\$ACPP_RT_LIB_DIR/hipSYCL/ext/cuda/nvvm/libdevice")

message(STATUS "cuda: app-config row is the discovered path under managed, \$ACPP_RT_LIB_DIR-relative under full")

# full with the gate off is a configure error: CUDA is nonpermissive, and
# shipping it without ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN is
# exactly the EULA decision the gate exists to force. FATAL_ERROR always
# terminates whichever process hits it - there is no in-process way to
# catch one - so this runs as its own child and checks the exit code.
execute_process(
  COMMAND ${CMAKE_COMMAND} -D "ACPP_DEPLOYMENT_STRATEGY=full" -P "${_inner}"
  OUTPUT_VARIABLE _ungated_out ERROR_VARIABLE _ungated_out2 RESULT_VARIABLE _ungated_res)
if(_ungated_res EQUAL 0)
  message(FATAL_ERROR
    "strategy 'full' with the gate off should have failed (CUDA is "
    "nonpermissive) but exited 0:\n${_ungated_out}\n${_ungated_out2}")
endif()
if(NOT "${_ungated_out2}" MATCHES "ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN")
  message(FATAL_ERROR
    "strategy 'full' with the gate off failed, but not for the gate reason:\n${_ungated_out2}")
endif()
message(STATUS "cuda: full with the gate off is a configure error, as declared")

# ---------------------------------------------------------------------------
# (d) Conda-shaped case: ACPP_CUDA_SUBDIR set to "" (installs straight at
#     the root) under full (shipped, gated) - the only strategy where
#     ACPP_CUDA_SUBDIR feeds into the app-config row at all; under
#     managed it is never read for that value (not shipped means the
#     discovered root, unrelated to our own subdir choice). cmake computes
#     the relative path itself now, via acpp_relative_from_rt_libdir/
#     acpp_join_relative, so an empty subdir is just one fewer path
#     segment - no doubled slash for a deploy engine to normalize later.
# ---------------------------------------------------------------------------

execute_process(
  COMMAND ${CMAKE_COMMAND}
    -D "ACPP_DEPLOYMENT_STRATEGY=full"
    -D "ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN=ON"
    -D "ACPP_CUDA_SUBDIR="
    -P "${_inner}"
  OUTPUT_VARIABLE _conda_out ERROR_VARIABLE _conda_out2 RESULT_VARIABLE _conda_res)
if(NOT _conda_res EQUAL 0)
  message(FATAL_ERROR "conda-shaped run failed:\n${_conda_out}\n${_conda_out2}")
endif()
set(_conda_out "${_conda_out}${_conda_out2}")

extract_result("${_conda_out}" "ACPP_CUDA_SUBDIR" _conda_subdir)
expect_eq(_conda_subdir "")
extract_result("${_conda_out}" "ACPP_APP_CUDA_LIBDEVICE_DIR" _conda_libdevice)
# Relative from "lib" (the runtime library's own install directory) to ""
# (the vendor subdir, installed at the root) is ".."; joined with the
# libdevice subdir fact, "../nvvm/libdevice" - normalized, no doubled "/".
expect_eq(_conda_libdevice "\$ACPP_RT_LIB_DIR/../nvvm/libdevice")
message(STATUS
  "cuda (conda-shaped, ACPP_CUDA_SUBDIR=\"\", full): '${_conda_libdevice}' - "
  "cmake normalizes the empty subdir itself at configure time, so there is "
  "no deploy-engine obligation left to document here.")

message(STATUS "verify-strategy-cuda: all checks passed")
