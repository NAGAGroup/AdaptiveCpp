# Vendor install rules (cmake/acpp-vendor-install.cmake), run with cmake -P:
#   cmake -P devops/verify/verify-vendor-install.cmake
#
# `cmake -P` parses install() but never executes it, so this harness
# exercises the configure-time parts directly, against a fake vendor tree
# built under /tmp with a real .so symlink chain (file(CREATE_LINK ...
# SYMBOLIC), matching how a real toolkit's runtime library ships:
# unversioned link -> soname link -> real versioned file), plus a plain
# file and an executable-shaped file for acpp_install_vendor_files, and a
# subdirectory for acpp_install_vendor_dir. Four things asserted:
#
#   (1) the resolver (name -> file list) finds every link in the chain.
#   (2) a missing library is a FATAL_ERROR, in a child process (a
#       FATAL_ERROR in-process would abort this harness itself).
#   (3) SHIPPED OFF: every helper is a no-op - ACPP_VENDOR_INSTALL_PLAN
#       stays empty.
#   (4) SHIPPED ON: ACPP_VENDOR_INSTALL_PLAN holds exactly the destination
#       paths expected for the lib chain, the plain/executable files, and
#       the directory.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-vendor-install.cmake)

# ---------------------------------------------------------------------------
# (0) The per-vendor install files parse clean on their own - the same
# whole-file, before-anything-executes rule verify-parse.cmake documents:
# each of these calls acpp_install_vendor_* functions this standalone
# `cmake -P` never defines, which fails at *run* time, not parse time, so
# it is not a failure this check looks for (see verify-parse.cmake's own
# header for the measured rule).
# ---------------------------------------------------------------------------

set(_install_files
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/install/windows/common/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/omp.cmake
  ${ACPP_REPO_ROOT}/cmake/install/macos/common/omp.cmake
  ${ACPP_REPO_ROOT}/cmake/install/windows/common/omp.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/hip.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/nvhpc.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/install/windows/common/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/ze.cmake
  ${ACPP_REPO_ROOT}/cmake/install/windows/common/ze.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/vk.cmake
  ${ACPP_REPO_ROOT}/cmake/install/macos/common/vk.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/clspv.cmake
  ${ACPP_REPO_ROOT}/cmake/install/macos/common/clspv.cmake
  ${ACPP_REPO_ROOT}/cmake/install/windows/common/clspv.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/common/core.cmake
  ${ACPP_REPO_ROOT}/cmake/install/linux/x86_64/core.cmake)
foreach(_f ${_install_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _install_err RESULT_VARIABLE _install_res)
  if(_install_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_install_err}")
  endif()
endforeach()
message(STATUS "verify-vendor-install: every per-vendor install file parses clean")

set(_root "/tmp/acpp-verify-vendor-install/root")
file(REMOVE_RECURSE "/tmp/acpp-verify-vendor-install")
file(MAKE_DIRECTORY "${_root}/inc")

file(WRITE "${_root}/libfoo.so.1.2.3" "")
file(CREATE_LINK "${_root}/libfoo.so.1.2.3" "${_root}/libfoo.so.1" SYMBOLIC)
file(CREATE_LINK "${_root}/libfoo.so.1" "${_root}/libfoo.so" SYMBOLIC)
file(WRITE "${_root}/readme.txt" "")
file(WRITE "${_root}/runme" "")
file(WRITE "${_root}/inc/header.h" "")

# ---------------------------------------------------------------------------
# (1) The resolver finds every link in the chain.
# ---------------------------------------------------------------------------

_acpp_resolve_vendor_lib_files(_chain "${_root}" "foo")
set(_expect_names "libfoo.so" "libfoo.so.1" "libfoo.so.1.2.3")
foreach(_name IN LISTS _expect_names)
  set(_found FALSE)
  foreach(_f IN LISTS _chain)
    get_filename_component(_fname "${_f}" NAME)
    if("${_fname}" STREQUAL "${_name}")
      set(_found TRUE)
    endif()
  endforeach()
  if(NOT _found)
    message(FATAL_ERROR "resolver: '${_name}' missing from resolved chain: ${_chain}")
  endif()
endforeach()
list(LENGTH _chain _chain_len)
if(NOT _chain_len EQUAL 3)
  message(FATAL_ERROR "resolver: expected exactly 3 files, got ${_chain_len}: ${_chain}")
endif()

message(STATUS "verify-vendor-install: resolver finds the whole symlink chain (${_chain_len} files)")

# ---------------------------------------------------------------------------
# (2) A missing library is a FATAL_ERROR, in a child process.
# ---------------------------------------------------------------------------

execute_process(
  COMMAND ${CMAKE_COMMAND}
    -D "ACPP_TEST_DIR=${_root}"
    -P "${CMAKE_CURRENT_LIST_DIR}/verify-vendor-install-inner.cmake"
  OUTPUT_VARIABLE _miss_out ERROR_VARIABLE _miss_err RESULT_VARIABLE _miss_res)
if(_miss_res EQUAL 0)
  message(FATAL_ERROR
    "missing-library case: should have failed but exited 0:\n${_miss_out}\n${_miss_err}")
endif()
if(NOT "${_miss_err}" MATCHES "doesnotexist")
  message(FATAL_ERROR
    "missing-library case: failed, but not for the missing-library reason:\n${_miss_err}")
endif()

message(STATUS "verify-vendor-install: a missing SHIPPED library is a configure error, as declared")

# ---------------------------------------------------------------------------
# (3) SHIPPED OFF: every helper is a no-op.
# ---------------------------------------------------------------------------

set(ACPP_FOO_SHIPPED OFF)
set(ACPP_FOO_DISCOVERED_ROOT "${_root}")
set(ACPP_FOO_SUBDIR "ext/foo")

acpp_install_vendor_libs(STEM FOO FACT "" NAMES foo)
acpp_install_vendor_files(STEM FOO FACT "" FILES readme.txt PROGRAMS runme)
acpp_install_vendor_dir(STEM FOO FACT "inc")

if(NOT "${ACPP_VENDOR_INSTALL_PLAN}" STREQUAL "")
  message(FATAL_ERROR
    "SHIPPED OFF: ACPP_VENDOR_INSTALL_PLAN should still be empty, holds: ${ACPP_VENDOR_INSTALL_PLAN}")
endif()

message(STATUS "verify-vendor-install: SHIPPED OFF declares nothing")

# ---------------------------------------------------------------------------
# (4) SHIPPED ON: the plan holds exactly the expected destination paths.
# ---------------------------------------------------------------------------

set(ACPP_FOO_SHIPPED ON)

acpp_install_vendor_libs(STEM FOO FACT "" NAMES foo)
acpp_install_vendor_files(STEM FOO FACT "" FILES readme.txt PROGRAMS runme)
acpp_install_vendor_dir(STEM FOO FACT "inc")

set(_expect_plan
  "ext/foo/libfoo.so"
  "ext/foo/libfoo.so.1"
  "ext/foo/libfoo.so.1.2.3"
  "ext/foo/readme.txt"
  "ext/foo/runme"
  "ext/foo/inc/")
foreach(_entry IN LISTS _expect_plan)
  list(FIND ACPP_VENDOR_INSTALL_PLAN "${_entry}" _idx)
  if(_idx EQUAL -1)
    message(FATAL_ERROR
      "SHIPPED ON: expected plan entry '${_entry}' missing, plan holds: ${ACPP_VENDOR_INSTALL_PLAN}")
  endif()
endforeach()
list(LENGTH ACPP_VENDOR_INSTALL_PLAN _plan_len)
list(LENGTH _expect_plan _expect_len)
if(NOT _plan_len EQUAL _expect_len)
  message(FATAL_ERROR
    "SHIPPED ON: plan has ${_plan_len} entries, expected ${_expect_len}: ${ACPP_VENDOR_INSTALL_PLAN}")
endif()

message(STATUS "verify-vendor-install: SHIPPED ON records exactly the expected destination paths")

# ---------------------------------------------------------------------------
# (5) hip (linux): the real install file, four facts, against a fake
# TheRock-shaped tree. SHIPPED OFF first (every call in the file a no-op),
# then SHIPPED ON, asserting the plan holds exactly the expected dest path
# for every fact: RT's seven libraries, SYSDEPS/BITCODE/INCLUDE as whole
# directories.
# ---------------------------------------------------------------------------

set(_hip_root "/tmp/acpp-verify-vendor-install/hip")
file(REMOVE_RECURSE "${_hip_root}")
file(MAKE_DIRECTORY "${_hip_root}/lib/rocm_sysdeps/lib")
file(MAKE_DIRECTORY "${_hip_root}/lib/llvm/amdgcn/bitcode")
file(MAKE_DIRECTORY "${_hip_root}/include/hip")

foreach(_hip_lib amdhip64 hsa-runtime64 amd_comgr hiprtc hiprtc-builtins rocprofiler-register rocm-core)
  file(WRITE "${_hip_root}/lib/lib${_hip_lib}.so" "")
endforeach()
file(WRITE "${_hip_root}/lib/rocm_sysdeps/lib/libsysdep.so" "")
file(WRITE "${_hip_root}/lib/llvm/amdgcn/bitcode/ockl.bc" "")
file(WRITE "${_hip_root}/include/hip/hip_runtime.h" "")

set(ACPP_HIP_DISCOVERED_ROOT "${_hip_root}")
set(ACPP_HIP_SUBDIR "ext/hip")
set(ACPP_HIP_RT_SUBDIR "lib")
set(ACPP_HIP_SYSDEPS_SUBDIR "lib/rocm_sysdeps/lib")
set(ACPP_HIP_BITCODE_SUBDIR "lib/llvm/amdgcn/bitcode")
set(ACPP_HIP_INCLUDE_SUBDIR "include")

set(ACPP_VENDOR_INSTALL_PLAN "")
set(ACPP_HIP_SHIPPED OFF)
include(${ACPP_REPO_ROOT}/cmake/install/linux/common/hip.cmake)
if(NOT "${ACPP_VENDOR_INSTALL_PLAN}" STREQUAL "")
  message(FATAL_ERROR
    "hip SHIPPED OFF: ACPP_VENDOR_INSTALL_PLAN should still be empty, holds: ${ACPP_VENDOR_INSTALL_PLAN}")
endif()
message(STATUS "verify-vendor-install: hip SHIPPED OFF declares nothing")

set(ACPP_HIP_SHIPPED ON)
include(${ACPP_REPO_ROOT}/cmake/install/linux/common/hip.cmake)

set(_expect_hip_plan
  "ext/hip/lib/libamdhip64.so"
  "ext/hip/lib/libhsa-runtime64.so"
  "ext/hip/lib/libamd_comgr.so"
  "ext/hip/lib/libhiprtc.so"
  "ext/hip/lib/libhiprtc-builtins.so"
  "ext/hip/lib/librocprofiler-register.so"
  "ext/hip/lib/librocm-core.so"
  "ext/hip/lib/rocm_sysdeps/lib/"
  "ext/hip/lib/llvm/amdgcn/bitcode/"
  "ext/hip/include/")
foreach(_entry IN LISTS _expect_hip_plan)
  list(FIND ACPP_VENDOR_INSTALL_PLAN "${_entry}" _idx)
  if(_idx EQUAL -1)
    message(FATAL_ERROR
      "hip SHIPPED ON: expected plan entry '${_entry}' missing, plan holds: ${ACPP_VENDOR_INSTALL_PLAN}")
  endif()
endforeach()
list(LENGTH ACPP_VENDOR_INSTALL_PLAN _hip_plan_len)
list(LENGTH _expect_hip_plan _hip_expect_len)
if(NOT _hip_plan_len EQUAL _hip_expect_len)
  message(FATAL_ERROR
    "hip SHIPPED ON: plan has ${_hip_plan_len} entries, expected ${_hip_expect_len}: ${ACPP_VENDOR_INSTALL_PLAN}")
endif()

message(STATUS "verify-vendor-install: hip SHIPPED ON records exactly the expected destination paths for every fact")

message(STATUS "verify-vendor-install: all checks passed")
