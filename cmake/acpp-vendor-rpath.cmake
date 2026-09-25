# Backends' rpaths to shipped vendors (doc/design-walkthrough-2026-09-25.md,
# Commit 3 step 3e). src/CMakeLists.txt sets `base` to $ORIGIN (@loader_path
# on macOS) and src/runtime/CMakeLists.txt/src/compiler/llvm-to-backend/
# CMakeLists.txt already set CMAKE_INSTALL_RPATH per directory for what a
# backend links against ours - this file adds the piece that was missing:
# reaching a SHIPPED vendor's own runtime libraries, which live under
# ACPP_<STEM>_SUBDIR, not under any of those fixed relative paths.
#
# Included early - before add_subdirectory(src) - unlike
# cmake/acpp-vendor-install.cmake's own per-unit install files (included
# after, since those only need to run once at the end): a backend target's
# INSTALL_RPATH must be appended while src/runtime/CMakeLists.txt and
# src/compiler/llvm-to-backend/CMakeLists.txt are themselves still running,
# during add_subdirectory(src). The options files (and hence every
# ACPP_<STEM>_SHIPPED/ACPP_<STEM>_SUBDIR) are already available by then -
# they run even earlier, alongside cmake/discovery.cmake.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/acpp-vendor-install.cmake)

# acpp_vendor_rpath_entry(<out_var> STEM <s> FACT <fact-or-empty>
#                          FROM <install-dir-of-the-binary>)
#
# <out_var> := "" unless ACPP_<STEM>_SHIPPED; otherwise
# "<base>/<relative path from FROM to ACPP_<STEM>_SUBDIR/<FACT>>", both
# sides install-root-relative (FROM the same way ACPP_<STEM>_SUBDIR always
# is), where <base> is the literal token $ORIGIN, or @loader_path on
# APPLE - a string the dynamic loader resolves at load time relative to
# the binary carrying it, never a cmake path itself. The relative path is
# computed with file(RELATIVE_PATH) against a dummy anchor shared by both
# sides (neither needs to exist; the anchor only makes both absolute, which
# file(RELATIVE_PATH) requires) - the same trick
# cmake/options/common/core.cmake's acpp_relative_from_rt_libdir uses for
# an application-configuration value's own equivalent computation. No
# doubled slashes: string(JOIN) inside _acpp_vi_join_relative already
# drops empty pieces, and this function only ever joins <base> with a
# single already-clean relative path, never concatenating raw pieces of
# its own.
function(acpp_vendor_rpath_entry out_var)
  cmake_parse_arguments(_avr "" "STEM;FACT;FROM" "" ${ARGN})
  if(NOT ACPP_${_avr_STEM}_SHIPPED)
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  _acpp_vi_join_relative(_avr_target "${ACPP_${_avr_STEM}_SUBDIR}" "${_avr_FACT}")

  set(_avr_anchor "/acpp-rpath-anchor")
  file(RELATIVE_PATH _avr_rel
    "${_avr_anchor}/${_avr_FROM}"
    "${_avr_anchor}/${_avr_target}")

  if(APPLE)
    set(_avr_base "@loader_path")
  else()
    set(_avr_base "$ORIGIN")
  endif()

  if("${_avr_rel}" STREQUAL "" OR "${_avr_rel}" STREQUAL ".")
    set(${out_var} "${_avr_base}" PARENT_SCOPE)
  else()
    set(${out_var} "${_avr_base}/${_avr_rel}" PARENT_SCOPE)
  endif()
endfunction()

# acpp_add_vendor_rpaths(<target> FROM <install-dir-of-the-binary>
#                         ENTRIES <STEM[:FACT]>...)
#
# Appends every non-empty acpp_vendor_rpath_entry() result to <target>'s
# INSTALL_RPATH property - not the CMAKE_INSTALL_RPATH variable, so this
# layers on top of whatever base rpath was already set (INSTALL_RPATH is
# only INITIALIZED from CMAKE_INSTALL_RPATH at add_library() time; setting
# the property afterward touches nothing else). A no-op on WIN32: Windows
# has no RPATH - a deployed application reaches a shipped vendor's DLL
# directory through the app config's ACPP_<VENDOR>_DLL_DIR/
# AddDllDirectory instead (doc/configuration-model.md, "Windows").
#
# Guards itself so callers never need to: a target that does not exist
# (its backend was disabled - WITH_*_BACKEND OFF for that add_library())
# and a vendor whose ACPP_<STEM>_SHIPPED is not even DEFINED (its options
# file was never included, e.g. a backend without its own vendor unit, or
# this build's platform never declares that vendor at all) are both
# silently skipped rather than erroring.
#
# Each ENTRIES item is "STEM" or "STEM:FACT" - "STEM" alone means the
# empty fact, a vendor with no internal lib/include/bin split (libomp,
# libnuma, sleef, amath, svml).
function(acpp_add_vendor_rpaths target)
  if(WIN32)
    return()
  endif()
  if(NOT TARGET ${target})
    return()
  endif()

  cmake_parse_arguments(_aar "" "FROM" "ENTRIES" ${ARGN})

  foreach(_aar_entry IN LISTS _aar_ENTRIES)
    string(REPLACE ":" ";" _aar_parts "${_aar_entry}")
    list(LENGTH _aar_parts _aar_n)
    list(GET _aar_parts 0 _aar_stem)
    if(_aar_n GREATER 1)
      list(GET _aar_parts 1 _aar_fact)
    else()
      set(_aar_fact "")
    endif()

    if(NOT DEFINED ACPP_${_aar_stem}_SHIPPED)
      continue()
    endif()

    acpp_vendor_rpath_entry(_aar_value STEM ${_aar_stem} FACT "${_aar_fact}" FROM "${_aar_FROM}")
    if(NOT "${_aar_value}" STREQUAL "")
      set_property(TARGET ${target} APPEND PROPERTY INSTALL_RPATH "${_aar_value}")
    endif()
  endforeach()
endfunction()
