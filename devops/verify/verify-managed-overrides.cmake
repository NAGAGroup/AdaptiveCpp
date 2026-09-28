# Managed root overrides (cmake/options/common/core.cmake's
# acpp_declare_vendor_root / acpp_declare_vendor_app_dir / _app_root, the
# -DACPP_<STEM>_ROOT knob), run with cmake -P:
#   cmake -P devops/verify/verify-managed-overrides.cmake
#
# A synthetic vendor (stem FOO, category permissive) rather than a real one,
# so a case can be run several times over with a fresh stem (FOOA, FOOB,
# ...) and nothing leaks between them. Four cases against the default
# strategy (managed, so every case is NOT SHIPPED): no override, an
# absolute override, a relative override, and a root-level relative
# override. Two error cases run as child processes (a FATAL_ERROR in-process
# would abort this harness itself, same reasoning as verify-vendor-install.
# cmake's own negative case): a SHIPPED vendor (strategy full) rejects any
# override, and a template value ("{{ ... }}") is never a valid override.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# Core stand-ins (same set verify-hip.cmake uses).
# ---------------------------------------------------------------------------
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21")
set(ACPP_DISCOVERED_CLANG_RESOURCE_REL "lib/clang/21")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

if(DEFINED ACPP_OVERRIDE_STRATEGY)
  set(ACPP_DEPLOYMENT_STRATEGY "${ACPP_OVERRIDE_STRATEGY}")
else()
  set(ACPP_DEPLOYMENT_STRATEGY "managed")
endif()

include(${ACPP_REPO_ROOT}/cmake/options/common/core.cmake)

# A synthetic vendor's discovery: one root, one RT subdir - enough to
# exercise every macro a real vendor.cmake file calls.
set(ACPP_DISCOVERED_FOO_PREFIX "/opt/foo")
set(ACPP_DISCOVERED_FOO_LIBDIR "lib")

# A macro, not a function: every ACPP_<stem>_* value it declares has to
# land in this script's own top-level scope for the assertions below to
# read, the same reason every acpp_declare_vendor* in core.cmake is itself
# a macro.
macro(run_case stem root)
  if(NOT "${root}" STREQUAL "")
    set(ACPP_${stem}_ROOT "${root}")
  endif()
  acpp_declare_vendor(${stem} foo permissive)
  acpp_declare_vendor_root(${stem} foo ACPP_DISCOVERED_FOO_PREFIX "${ACPP_DISCOVERED_FOO_PREFIX}")
  acpp_declare_vendor_subdir_fact(${stem} RT ACPP_DISCOVERED_FOO_LIBDIR "${ACPP_DISCOVERED_FOO_LIBDIR}")
  acpp_declare_vendor_app_dir(${stem} foo RT)
  acpp_declare_vendor_app_root(${stem} foo)
endmacro()

# ---------------------------------------------------------------------------
# Child dispatch: run exactly one error case and stop, so the parent
# process (below) never reaches a FATAL_ERROR itself.
# ---------------------------------------------------------------------------
if(DEFINED ACPP_OVERRIDE_CHILD)
  if(ACPP_OVERRIDE_CHILD STREQUAL "full")
    run_case(FOOFULL "/srv/x")
  elseif(ACPP_OVERRIDE_CHILD STREQUAL "template")
    run_case(FOOTMPL "{{ acpp-root }}/x")
  elseif(ACPP_OVERRIDE_CHILD STREQUAL "svml-gate")
    acpp_declare_vendor(SVMLX svmlx nonpermissive "/opt/intel/lib")
  elseif(ACPP_OVERRIDE_CHILD STREQUAL "svml-notfound")
    acpp_declare_vendor(SVMLY svmly nonpermissive "")
  else()
    message(FATAL_ERROR "verify-managed-overrides: unknown ACPP_OVERRIDE_CHILD '${ACPP_OVERRIDE_CHILD}'")
  endif()
  message(STATUS "verify-managed-overrides (child ${ACPP_OVERRIDE_CHILD}): did not fail")
  return()
endif()

# ---------------------------------------------------------------------------
# FOOA: no override - the discovered root and its subdirs pass straight
# through, unchanged from before this commit.
# ---------------------------------------------------------------------------
run_case(FOOA "")
expect_eq(ACPP_FOOA_INSTALL_ROOT "/opt/foo")
expect_eq(ACPP_APP_FOOA_RT_DIR "/opt/foo/lib")
expect_eq(ACPP_APP_FOOA_INSTALL_ROOT "/opt/foo")
message(STATUS "verify-managed-overrides: FOOA (no override) - discovered root passes through")

# ---------------------------------------------------------------------------
# FOOB: an absolute override - used as-is on both sides, trailing slash
# stripped.
# ---------------------------------------------------------------------------
run_case(FOOB "/srv/vendor/foo/")
expect_eq(ACPP_FOOB_INSTALL_ROOT "/srv/vendor/foo")
expect_eq(ACPP_APP_FOOB_RT_DIR "/srv/vendor/foo/lib")
expect_eq(ACPP_APP_FOOB_INSTALL_ROOT "/srv/vendor/foo")
message(STATUS "verify-managed-overrides: FOOB (absolute override) - used as-is, trailing slash stripped")

# ---------------------------------------------------------------------------
# FOOC: a relative override - relative to the install prefix on the driver
# side, $ACPP_RT_LIB_DIR-relative on the application side.
# ---------------------------------------------------------------------------
run_case(FOOC "vendor/foo")
expect_eq(ACPP_FOOC_INSTALL_ROOT "{{ acpp-root }}/vendor/foo")
expect_eq(ACPP_APP_FOOC_RT_DIR "\$ACPP_RT_LIB_DIR/../vendor/foo/lib")
expect_eq(ACPP_APP_FOOC_INSTALL_ROOT "\$ACPP_RT_LIB_DIR/../vendor/foo")
message(STATUS "verify-managed-overrides: FOOC (relative override) - relative to the install prefix, both sides")

# ---------------------------------------------------------------------------
# FOOD: a root-level relative override ("./lib/") - leading "./" and
# trailing "/" stripped; it resolves to the runtime libdir itself, so the
# application side lands exactly at $ACPP_RT_LIB_DIR.
# ---------------------------------------------------------------------------
run_case(FOOD "./lib/")
expect_eq(ACPP_FOOD_INSTALL_ROOT "{{ acpp-root }}/lib")
expect_eq(ACPP_APP_FOOD_INSTALL_ROOT "\$ACPP_RT_LIB_DIR")
message(STATUS "verify-managed-overrides: FOOD (root-level relative override) - ./ and trailing / stripped")

# ---------------------------------------------------------------------------
# Conda-layout cases: what ACPP_<STEM>_ROOT="." actually produces for a
# real multi-subdir vendor (CUDA: RT + BITCODE) and a single-subdir one
# (OCL/ZE: BIN) on both platform shapes, plus LIBOMP's own single-root
# form on each. WIN32 is simulated the same way verify-app-rpath.cmake and
# verify-vendor-rpath.cmake simulate a platform: set(WIN32 TRUE)/unset(WIN32)
# around acpp_relative_from_rt_libdir's own WIN32 branch (core.cmake:108-121),
# which is what picks CMAKE_INSTALL_BINDIR over CMAKE_INSTALL_LIBDIR as
# $ACPP_RT_LIB_DIR's anchor.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# CUDAA: Linux-shaped conda CUDA. Discovered prefix /p, RT subdir
# "targets/x86_64-linux/lib" (conda's runtime split), BITCODE subdir
# "nvvm/libdevice". ACPP_CUDA_ROOT="." is root-level-relative: one level up
# from $ACPP_RT_LIB_DIR (lib), the same shape as FOOD's "./lib/" but
# starting from "." itself.
# ---------------------------------------------------------------------------
set(ACPP_DISCOVERED_CUDAA_PREFIX "/p")
set(ACPP_CUDAA_ROOT ".")
acpp_declare_vendor(CUDAA cudaa permissive)
acpp_declare_vendor_root(CUDAA cudaa ACPP_DISCOVERED_CUDAA_PREFIX "${ACPP_DISCOVERED_CUDAA_PREFIX}")
set(ACPP_DISCOVERED_CUDAA_RT "targets/x86_64-linux/lib")
set(ACPP_DISCOVERED_CUDAA_BITCODE "nvvm/libdevice")
acpp_declare_vendor_subdir_fact(CUDAA RT ACPP_DISCOVERED_CUDAA_RT "targets/x86_64-linux/lib")
acpp_declare_vendor_subdir_fact(CUDAA BITCODE ACPP_DISCOVERED_CUDAA_BITCODE "nvvm/libdevice")
acpp_declare_vendor_app_dir(CUDAA cudaa RT)
acpp_declare_vendor_app_dir(CUDAA cudaa BITCODE)
expect_eq(ACPP_APP_CUDAA_BITCODE_DIR "\$ACPP_RT_LIB_DIR/../nvvm/libdevice")
message(STATUS "verify-managed-overrides: CUDAA (linux-shaped conda CUDA, ROOT=.) - libdevice at \$ACPP_RT_LIB_DIR/../nvvm/libdevice, RT at ${ACPP_APP_CUDAA_RT_DIR}")

# ---------------------------------------------------------------------------
# CUDAB: Windows-shaped conda CUDA. WIN32 -> $ACPP_RT_LIB_DIR anchors on
# CMAKE_INSTALL_BINDIR (bin). Discovered prefix /p/Library, RT subdir "bin"
# (the DLL's own directory), BITCODE subdir "nvvm/libdevice". Same
# ACPP_CUDA_ROOT="." override.
# ---------------------------------------------------------------------------
set(WIN32 TRUE)
set(ACPP_DISCOVERED_CUDAB_PREFIX "/p/Library")
set(ACPP_CUDAB_ROOT ".")
acpp_declare_vendor(CUDAB cudab permissive)
acpp_declare_vendor_root(CUDAB cudab ACPP_DISCOVERED_CUDAB_PREFIX "${ACPP_DISCOVERED_CUDAB_PREFIX}")
set(ACPP_DISCOVERED_CUDAB_RT "bin")
set(ACPP_DISCOVERED_CUDAB_BITCODE "nvvm/libdevice")
acpp_declare_vendor_subdir_fact(CUDAB RT ACPP_DISCOVERED_CUDAB_RT "bin")
acpp_declare_vendor_subdir_fact(CUDAB BITCODE ACPP_DISCOVERED_CUDAB_BITCODE "nvvm/libdevice")
acpp_declare_vendor_app_dir(CUDAB cudab RT)
acpp_declare_vendor_app_dir(CUDAB cudab BITCODE)
expect_eq(ACPP_APP_CUDAB_BITCODE_DIR "\$ACPP_RT_LIB_DIR/../nvvm/libdevice")
# The DLL dir round-trips through the runtime bindir itself
# ($ACPP_RT_LIB_DIR/../bin == $ACPP_RT_LIB_DIR at runtime once resolved) -
# acpp_join_absolute never collapses ".."; assert what the code actually
# produces, unsimplified.
expect_eq(ACPP_APP_CUDAB_RT_DIR "\$ACPP_RT_LIB_DIR/../bin")
message(STATUS "verify-managed-overrides: CUDAB (windows-shaped conda CUDA, ROOT=.) - libdevice at \$ACPP_RT_LIB_DIR/../nvvm/libdevice, DLL at \$ACPP_RT_LIB_DIR/../bin")

# ---------------------------------------------------------------------------
# OCLW / ZEW: Windows OpenCL and Level Zero, single BIN subdir "bin",
# ACPP_<STEM>_ROOT="." - same shape as CUDAB's RT side, no BITCODE.
# ---------------------------------------------------------------------------
set(ACPP_DISCOVERED_OCLW_PREFIX "/p/Library")
set(ACPP_OCLW_ROOT ".")
acpp_declare_vendor(OCLW oclw permissive)
acpp_declare_vendor_root(OCLW oclw ACPP_DISCOVERED_OCLW_PREFIX "${ACPP_DISCOVERED_OCLW_PREFIX}")
set(ACPP_DISCOVERED_OCLW_BIN "bin")
acpp_declare_vendor_subdir_fact(OCLW BIN ACPP_DISCOVERED_OCLW_BIN "bin")
acpp_declare_vendor_app_dir(OCLW oclw BIN)
expect_eq(ACPP_APP_OCLW_BIN_DIR "\$ACPP_RT_LIB_DIR/../bin")
message(STATUS "verify-managed-overrides: OCLW (windows OpenCL, ROOT=.) - BIN at \$ACPP_RT_LIB_DIR/../bin")

set(ACPP_DISCOVERED_ZEW_PREFIX "/p/Library")
set(ACPP_ZEW_ROOT ".")
acpp_declare_vendor(ZEW zew permissive)
acpp_declare_vendor_root(ZEW zew ACPP_DISCOVERED_ZEW_PREFIX "${ACPP_DISCOVERED_ZEW_PREFIX}")
set(ACPP_DISCOVERED_ZEW_BIN "bin")
acpp_declare_vendor_subdir_fact(ZEW BIN ACPP_DISCOVERED_ZEW_BIN "bin")
acpp_declare_vendor_app_dir(ZEW zew BIN)
expect_eq(ACPP_APP_ZEW_BIN_DIR "\$ACPP_RT_LIB_DIR/../bin")
message(STATUS "verify-managed-overrides: ZEW (windows Level Zero, ROOT=.) - BIN at \$ACPP_RT_LIB_DIR/../bin")

unset(WIN32)

# ---------------------------------------------------------------------------
# LIBOMP: single-root vendor (no subdir breakdown). Windows
# ACPP_LIBOMP_ROOT="bin" and linux ACPP_LIBOMP_ROOT="lib" both name the
# runtime libdir itself, so both resolve to exactly $ACPP_RT_LIB_DIR - the
# same shape as FOOD's "./lib/" case, using run_case directly (it already
# declares an app_root, which is all a single-root vendor needs).
# ---------------------------------------------------------------------------
set(WIN32 TRUE)
run_case(LIBOMPW "bin")
expect_eq(ACPP_APP_LIBOMPW_INSTALL_ROOT "\$ACPP_RT_LIB_DIR")
unset(WIN32)
message(STATUS "verify-managed-overrides: LIBOMPW (windows libomp, ROOT=bin) - \$ACPP_RT_LIB_DIR")

run_case(LIBOMPL "lib")
expect_eq(ACPP_APP_LIBOMPL_INSTALL_ROOT "\$ACPP_RT_LIB_DIR")
message(STATUS "verify-managed-overrides: LIBOMPL (linux libomp, ROOT=lib) - \$ACPP_RT_LIB_DIR")

# ---------------------------------------------------------------------------
# Error case: a SHIPPED vendor (strategy full) rejects any override.
# ---------------------------------------------------------------------------
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -DACPP_OVERRIDE_STRATEGY=full
    -DACPP_OVERRIDE_CHILD=full
    -P "${CMAKE_CURRENT_LIST_FILE}"
  RESULT_VARIABLE _full_res ERROR_VARIABLE _full_err OUTPUT_VARIABLE _full_out)
if(_full_res EQUAL 0)
  message(FATAL_ERROR
    "full case: should have failed but exited 0:\n${_full_out}\n${_full_err}")
endif()
if(NOT "${_full_err}${_full_out}" MATCHES "takes no override")
  message(FATAL_ERROR
    "full case: failed, but not for the 'takes no override' reason:\n${_full_err}\n${_full_out}")
endif()
message(STATUS "verify-managed-overrides: a shipped vendor rejects ACPP_<STEM>_ROOT ('takes no override')")

# ---------------------------------------------------------------------------
# Error case: a template value is never a valid override.
# ---------------------------------------------------------------------------
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -DACPP_OVERRIDE_CHILD=template
    -P "${CMAKE_CURRENT_LIST_FILE}"
  RESULT_VARIABLE _tmpl_res ERROR_VARIABLE _tmpl_err OUTPUT_VARIABLE _tmpl_out)
if(_tmpl_res EQUAL 0)
  message(FATAL_ERROR
    "template case: should have failed but exited 0:\n${_tmpl_out}\n${_tmpl_err}")
endif()
if(NOT "${_tmpl_err}${_tmpl_out}" MATCHES "plain path")
  message(FATAL_ERROR
    "template case: failed, but not for the 'plain path' reason:\n${_tmpl_err}\n${_tmpl_out}")
endif()
message(STATUS "verify-managed-overrides: a template value is rejected ('plain path')")

# ---------------------------------------------------------------------------
# Error case: a nonpermissive vendor found and shipped under full, with the
# redistribution gate off, refuses to ship it.
# ---------------------------------------------------------------------------
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -DACPP_OVERRIDE_STRATEGY=full
    -DACPP_OVERRIDE_CHILD=svml-gate
    -P "${CMAKE_CURRENT_LIST_FILE}"
  RESULT_VARIABLE _svmlgate_res ERROR_VARIABLE _svmlgate_err OUTPUT_VARIABLE _svmlgate_out)
if(_svmlgate_res EQUAL 0)
  message(FATAL_ERROR
    "svml-gate case: should have failed but exited 0:\n${_svmlgate_out}\n${_svmlgate_err}")
endif()
if(NOT "${_svmlgate_err}${_svmlgate_out}" MATCHES "ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN")
  message(FATAL_ERROR
    "svml-gate case: failed, but not for the redistribution-gate reason:\n${_svmlgate_err}\n${_svmlgate_out}")
endif()
message(STATUS "verify-managed-overrides: a found nonpermissive vendor under full with the gate off refuses to ship ('ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN')")

# ---------------------------------------------------------------------------
# Non-error case: a nonpermissive vendor NOT found under full needs no
# redistribution decision, so the gate does not apply and nothing fails.
# ---------------------------------------------------------------------------
execute_process(
  COMMAND ${CMAKE_COMMAND}
    -DACPP_OVERRIDE_STRATEGY=full
    -DACPP_OVERRIDE_CHILD=svml-notfound
    -P "${CMAKE_CURRENT_LIST_FILE}"
  RESULT_VARIABLE _svmlnf_res ERROR_VARIABLE _svmlnf_err OUTPUT_VARIABLE _svmlnf_out)
if(NOT _svmlnf_res EQUAL 0)
  message(FATAL_ERROR
    "svml-notfound case: should not have failed:\n${_svmlnf_out}\n${_svmlnf_err}")
endif()
message(STATUS "verify-managed-overrides: a not-found nonpermissive vendor under full needs no redistribution decision")

message(STATUS "verify-managed-overrides: OK")
