# The generator check: acpp_generate_installed_configs, run with cmake -P:
#   cmake -P devops/verify/verify-installed-configs.cmake
#
# linux/x86_64, toolchain mode, core + cuda - the same discovery stand-ins
# verify-core.cmake uses, the same CUDA stand-ins verify-cuda.cmake uses.
# Three cases:
#
#   - managed, run in-process (this file's own process, the only inclusion
#     of core.cmake/cuda.cmake it needs): asserts no acpp-deploy.json is
#     written (managed ships nothing) and the app config's
#     ACPP_CUDA_LIBDEVICE_DIR line is the discovered absolute path (CUDA is
#     not shipped, so the driver's own machine copy is what the app is
#     told to use).
#
#   - full with the redistribution gate ON, run as a child process
#     (verify-installed-configs-inner.cmake) because include_guard(GLOBAL)
#     forbids including core.cmake/cuda.cmake twice in one process: asserts
#     acpp-deploy.json exists, carries no build-mode or unless key anywhere
#     (every kept row had both stripped - and since no build-mode: plugin
#     row exists anywhere in the fixtures this harness merges right now,
#     "no build-mode key survives" doubles as the only exercisable proof
#     that a plugin-only row would have been dropped, not just stripped),
#     carries the omp vendor's row, and the app config's libdevice line is
#     $ACPP_RT_LIB_DIR-relative (CUDA is shipped, permissive gate
#     satisfied).
#
#   - a negative case, also a child process: unsetting a variable a
#     template references (ACPP_APP_CUDA_LIBDEVICE_DIR, cuda's app-config
#     fragment) before generating must FATAL_ERROR, not silently write an
#     empty value.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(_inner "${CMAKE_CURRENT_LIST_DIR}/verify-installed-configs-inner.cmake")

# ---------------------------------------------------------------------------
# managed (in-process): nothing is shipped.
# ---------------------------------------------------------------------------

set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "/opt/amath/lib")
set(ACPP_DISCOVERED_SVML_DIR "")

set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")
set(LLVM_VERSION_MAJOR "21")

# Stand-in for the top-level CMakeLists.txt's own project(VERSION ...)
# setup, which no options file computes - config/common/core.json reads
# these directly. Matches CMakeLists.txt's own current values.
set(ACPP_VERSION_MAJOR "25")
set(ACPP_VERSION_MINOR "10")
set(ACPP_VERSION_PATCH "0")
set(ACPP_VERSION_SUFFIX "")

set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
set(ACPP_LIBOMP_SOURCE_DIR "/usr/lib/llvm-21/lib")

set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)
include(${ACPP_REPO_ROOT}/cmake/acpp-installed-configs.cmake)

# ---------------------------------------------------------------------------
# _acpp_filter_deploy_group's two HIP-specific unless conditions, exercised
# directly against a hand-built row for each, both ways (dropped, kept) -
# neither condition depends on anything else acpp_generate_installed_configs
# assembles, so a full generate is not needed to prove either one.
# ---------------------------------------------------------------------------

function(_verify_unless_case label unless_key control_var drop_value keep_value)
  set(_row "{\"unless\":\"${unless_key}\",\"src\":\"x\",\"dest\":\"y\",\"files\":[\"*\"]}")
  set(_arr "[${_row}]")

  set(${control_var} "${drop_value}")
  _acpp_filter_deploy_group(_kept_dropped "${_arr}")
  string(JSON _n_dropped LENGTH "${_kept_dropped}")
  if(NOT _n_dropped EQUAL 0)
    message(FATAL_ERROR
      "${label}: row should have been dropped when ${control_var}='${drop_value}', kept: ${_kept_dropped}")
  endif()

  set(${control_var} "${keep_value}")
  _acpp_filter_deploy_group(_kept_kept "${_arr}")
  string(JSON _n_kept LENGTH "${_kept_kept}")
  if(NOT _n_kept EQUAL 1)
    message(FATAL_ERROR
      "${label}: row should have been kept when ${control_var}='${keep_value}', holds: ${_kept_kept}")
  endif()
  string(JSON _kept_unless ERROR_VARIABLE _kept_unless_err GET "${_kept_kept}" 0 "unless")
  if(NOT _kept_unless_err)
    message(FATAL_ERROR "${label}: kept row still carries its unless key: ${_kept_kept}")
  endif()

  message(STATUS "verify-installed-configs: ${label} - dropped when set, kept (unless stripped) otherwise")
endfunction()

_verify_unless_case("unless: hiprtc-link" "hiprtc-link" ACPP_DISCOVERED_HIP_HIPRTC ON OFF)
_verify_unless_case("unless: hip-no-sysdeps" "hip-no-sysdeps" ACPP_DISCOVERED_HIP_SYSDEPS_DIR "" "/opt/rocm/lib/rocm_sysdeps/lib")

set(_managed_dir "/tmp/acpp-verify-installed-configs-managed")
file(REMOVE_RECURSE "${_managed_dir}")

acpp_generate_installed_configs(
  PLATFORM linux
  ARCH x86_64
  UNITS cuda
  OUT_DIR "${_managed_dir}")

if(EXISTS "${_managed_dir}/acpp-deploy.json")
  message(FATAL_ERROR
    "managed: acpp-deploy.json should not be written - nothing is shipped under managed")
endif()

file(READ "${_managed_dir}/acpp-app.cfg" _managed_app_text)
if(NOT "${_managed_app_text}" MATCHES "ACPP_CUDA_LIBDEVICE_DIR=/usr/local/cuda-12\\.9/nvvm/libdevice")
  message(FATAL_ERROR
    "managed: acpp-app.cfg's ACPP_CUDA_LIBDEVICE_DIR line is not the discovered absolute path:\n${_managed_app_text}")
endif()

message(STATUS
  "verify-installed-configs (managed): no manifest written, app config names the discovered CUDA path")

# ---------------------------------------------------------------------------
# full, gate ON (child process): CUDA and libomp are both shipped.
# ---------------------------------------------------------------------------

set(_full_dir "/tmp/acpp-verify-installed-configs-full")
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -D "ACPP_DEPLOYMENT_STRATEGY=full"
    -D "ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN=ON"
    -D "ACPP_OUT_DIR=${_full_dir}"
    -P "${_inner}"
  OUTPUT_VARIABLE _full_out ERROR_VARIABLE _full_err RESULT_VARIABLE _full_res)
if(NOT _full_res EQUAL 0)
  message(FATAL_ERROR "full (gate ON) inner run failed:\n${_full_out}\n${_full_err}")
endif()

if(NOT EXISTS "${_full_dir}/acpp-deploy.json")
  message(FATAL_ERROR "full: acpp-deploy.json was not written")
endif()
file(READ "${_full_dir}/acpp-deploy.json" _full_deploy_text)
if("${_full_deploy_text}" MATCHES "build-mode")
  message(FATAL_ERROR
    "full: acpp-deploy.json still carries a build-mode key:\n${_full_deploy_text}")
endif()
if("${_full_deploy_text}" MATCHES "\"unless\"")
  message(FATAL_ERROR
    "full: acpp-deploy.json still carries an unless key:\n${_full_deploy_text}")
endif()
if(NOT "${_full_deploy_text}" MATCHES "libomp-name")
  message(FATAL_ERROR
    "full: acpp-deploy.json is missing the omp vendor's row:\n${_full_deploy_text}")
endif()

file(READ "${_full_dir}/acpp-app.cfg" _full_app_text)
if(NOT "${_full_app_text}" MATCHES "ACPP_CUDA_LIBDEVICE_DIR=\\$ACPP_RT_LIB_DIR/")
  message(FATAL_ERROR
    "full: acpp-app.cfg's ACPP_CUDA_LIBDEVICE_DIR line does not start with \$ACPP_RT_LIB_DIR/:\n${_full_app_text}")
endif()

message(STATUS
  "verify-installed-configs (full, gate ON): manifest written, build-mode/unless stripped, omp row present, libdevice line is \$ACPP_RT_LIB_DIR-relative")

# ---------------------------------------------------------------------------
# Negative case (child process): a template referencing an undefined @VAR@
# must FATAL_ERROR, not silently write an empty value.
# ---------------------------------------------------------------------------

set(_neg_dir "/tmp/acpp-verify-installed-configs-negative")
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -D "ACPP_TEST_UNSET_VAR=ACPP_APP_CUDA_LIBDEVICE_DIR"
    -D "ACPP_OUT_DIR=${_neg_dir}"
    -P "${_inner}"
  OUTPUT_VARIABLE _neg_out ERROR_VARIABLE _neg_err RESULT_VARIABLE _neg_res)
if(_neg_res EQUAL 0)
  message(FATAL_ERROR
    "negative case: generating with ACPP_APP_CUDA_LIBDEVICE_DIR unset should have failed but exited 0:\n${_neg_out}\n${_neg_err}")
endif()
if(NOT "${_neg_err}" MATCHES "ACPP_APP_CUDA_LIBDEVICE_DIR")
  message(FATAL_ERROR
    "negative case: failed, but not for the undefined-variable reason:\n${_neg_err}")
endif()

message(STATUS
  "verify-installed-configs (negative): undefined @VAR@ is a configure error, as declared")

message(STATUS "verify-installed-configs: all checks passed")
