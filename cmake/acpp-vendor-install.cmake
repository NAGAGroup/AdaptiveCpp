# Per-vendor cmake install rules: home (a)+(b) of the three-part manifest
# (doc/configuration-model.md, "The manifest"). Under full or
# full-permissive-only, a SHIPPED vendor (ACPP_<STEM>_SHIPPED ON) is copied
# at `cmake --install` time into ${CMAKE_INSTALL_PREFIX}/<ACPP_<STEM>_SUBDIR>
# /<fact subdir>, in the vendor's own layout. Every helper below is a no-op
# unless the vendor it names is SHIPPED - not shipped means the driver
# reaches the vendor in place, nothing to copy.
#
# The install lists these helpers build are written explicitly, per vendor,
# in cmake/install/<platform>/common/<unit>.cmake - deliberately NOT derived
# from the deploy manifest (config/*/deploy/<unit>.json): the manifest is
# drive-time configuration a downstream toolchain user may edit; the install
# rule is a package-time decision about what physically ships. A later sync
# harness (owed, not yet written - see doc/source-obligations.md) compares
# the two so they cannot silently drift, but neither is ever generated from
# the other. So a vendor's install file lists BOTH the toolchain-only pieces
# its manifest never deploys (headers, ptxas/fatbinary-class tools, import
# libraries) AND everything the manifest deploys with an application.
#
# Self-contained on purpose: only cmake/options/common/core.cmake's
# acpp_declare_vendor* macros are assumed to have already run (they set
# ACPP_<STEM>_SHIPPED, ACPP_<STEM>_SUBDIR, ACPP_<STEM>_DISCOVERED_ROOT before
# any helper here is ever called) - but the tiny path-joining this file
# needs of its own is reimplemented locally rather than pulled in from
# core.cmake, so a harness can include this file alone against a handful of
# hand-set ACPP_<STEM>_* variables, the same way cmake/acpp-config-merge.cmake
# stands alone from the options model that also uses it.

include_guard(GLOBAL)

# This file's own absolute path, computed once at file scope (not inside a
# function - CMAKE_CURRENT_LIST_FILE there would be wherever a *caller*
# happens to sit) - baked into every install(CODE) block below so it can
# re-include this file at `cmake --install` time, in the freshly spawned
# cmake_install.cmake process, which shares nothing from this configure
# run except what such a block explicitly re-establishes. Mirrors how
# cmake/acpp-config-merge.cmake computes its own repo root once, at file
# scope, for the same reason.
set(_ACPP_VENDOR_INSTALL_SELF "${CMAKE_CURRENT_LIST_FILE}")

# ACPP_VENDOR_INSTALL_PLAN: every acpp_install_vendor_* call that actually
# schedules a copy (SHIPPED only) appends the destination path(s) here,
# ACPP_<STEM>_SUBDIR-relative - a record a harness can inspect under plain
# `cmake -P`, where the install(CODE) blocks these functions also queue
# never run (cmake -P parses install() but does not execute it). Not
# shipped means nothing is appended - the plan's emptiness is exactly what
# a harness asserts in that case.
if(NOT DEFINED ACPP_VENDOR_INSTALL_PLAN)
  set(ACPP_VENDOR_INSTALL_PLAN "")
endif()

# install() is rejected outright under `cmake -P` ("install command is not
# scriptable") - not skipped, an error, regardless of what it would do -
# so every helper below guards its install(CODE ...) call on
# CMAKE_SCRIPT_MODE_FILE (only ever defined in script mode) rather than
# letting a harness's mere call to a SHIPPED helper abort the script. The
# plan-recording half runs either way: that half is what a harness under
# `cmake -P` can and does inspect (see devops/verify/verify-vendor-install.
# cmake); the install(CODE ...) half is what a real `cmake --install` runs.

# ---------------------------------------------------------------------------
# Small path helpers, local to this file (see the header comment for why
# they are not shared with cmake/options/common/core.cmake's
# identical-in-spirit acpp_join_relative/acpp_join_absolute).
# ---------------------------------------------------------------------------

function(_acpp_vi_join_relative out_var)
  set(_acpp_vi_pieces "")
  foreach(_acpp_vi_piece IN LISTS ARGN)
    string(REGEX REPLACE "^/+|/+$" "" _acpp_vi_piece "${_acpp_vi_piece}")
    if(NOT "${_acpp_vi_piece}" STREQUAL "")
      list(APPEND _acpp_vi_pieces "${_acpp_vi_piece}")
    endif()
  endforeach()
  list(LENGTH _acpp_vi_pieces _acpp_vi_n)
  if(_acpp_vi_n EQUAL 0)
    set(${out_var} "" PARENT_SCOPE)
  else()
    string(JOIN "/" _acpp_vi_joined ${_acpp_vi_pieces})
    set(${out_var} "${_acpp_vi_joined}" PARENT_SCOPE)
  endif()
endfunction()

function(_acpp_vi_join_absolute out_var root piece)
  if("${root}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()
  string(REGEX REPLACE "/+$" "" _acpp_vi_root "${root}")
  string(REGEX REPLACE "^/+|/+$" "" _acpp_vi_piece "${piece}")
  if("${_acpp_vi_piece}" STREQUAL "")
    set(${out_var} "${_acpp_vi_root}" PARENT_SCOPE)
  else()
    set(${out_var} "${_acpp_vi_root}/${_acpp_vi_piece}" PARENT_SCOPE)
  endif()
endfunction()

# ---------------------------------------------------------------------------
# The resolver: name -> the platform's file(s) for one shared library.
# ---------------------------------------------------------------------------
#
# Linux/other Unix: every "lib<name>.so*" file in the directory - the
# unversioned link (if present), the soname link, the real versioned file,
# in that likely order. list(SORT)'s default lexicographic compare puts a
# strict string prefix before anything that extends it, e.g. "libfoo.so"
# before "libfoo.so.1" before "libfoo.so.1.2.3" - true for any chain whose
# successive suffixes strictly extend the last, which is the ordinary case;
# it is not a numeric sort, so e.g. ".so.2" would wrongly sort after
# ".so.12", a case this codebase's own shipped vendors do not hit.
# macOS: every "lib<name>*.dylib" - dylib version numbers land before the
# extension, not after, so the name itself is still the sort anchor.
# Windows: the single "<name>.dll", or "lib<name>.dll" if that is what
# exists instead - Windows has no symlink chain, but it does have both
# naming conventions in the wild (CUDA ships "cudart64_<major>.dll", no
# prefix; LLVM's OpenMP runtime ships "libomp.dll", with one - matching the
# "-llibomp" this codebase's own Windows sequential link line already
# names). Checking both means a packager's ACPP_<VENDOR>_NAME never has to
# encode which convention its vendor happens to follow.
# Empty list, not an error, when nothing matches; the caller decides.
function(_acpp_resolve_vendor_lib_files out_var dir name)
  set(_acpp_found "")
  if(WIN32)
    if(EXISTS "${dir}/${name}.dll")
      set(_acpp_found "${dir}/${name}.dll")
    elseif(EXISTS "${dir}/lib${name}.dll")
      set(_acpp_found "${dir}/lib${name}.dll")
    endif()
  elseif(APPLE)
    file(GLOB _acpp_found LIST_DIRECTORIES false "${dir}/lib${name}*.dylib")
  else()
    file(GLOB _acpp_found LIST_DIRECTORIES false "${dir}/lib${name}.so*")
  endif()
  if(_acpp_found)
    list(SORT _acpp_found)
  endif()
  set(${out_var} "${_acpp_found}" PARENT_SCOPE)
endfunction()

# Install-time counterpart: resolves and copies (with the whole symlink
# chain preserved via FOLLOW_SYMLINK_CHAIN, starting from the shortest -
# topmost - resolved name) or FATAL_ERRORs naming what is missing and
# where. Defined here, not inlined into an install(CODE) string, so both
# the immediate path (acpp_install_vendor_libs, below, when the source
# directory already exists at configure time) and the deferred path (when
# it does not yet - see cmake/install/*/common/omp.cmake) share one
# implementation: an install(CODE) block re-includes this file (cheap -
# include_guard(GLOBAL) makes a second include of it in the same process a
# no-op) and calls this function itself, at `cmake --install` time, in the
# freshly-invoked cmake_install.cmake script's own process.
function(_acpp_install_vendor_lib_now dir destdir name)
  _acpp_resolve_vendor_lib_files(_acpp_files "${dir}" "${name}")
  if(NOT _acpp_files)
    message(FATAL_ERROR
      "Vendor library '${name}' was not found under ${dir}. A SHIPPED "
      "vendor's assets must exist by the time they are installed.")
  endif()
  list(GET _acpp_files 0 _acpp_entry)
  file(INSTALL "${_acpp_entry}" DESTINATION "${destdir}" FOLLOW_SYMLINK_CHAIN)
endfunction()

# ---------------------------------------------------------------------------
# Public helpers - every one a no-op unless ACPP_<STEM>_SHIPPED.
# ---------------------------------------------------------------------------

# acpp_install_vendor_libs(STEM <s> FACT <fact-or-empty> NAMES <names...>)
#
# One or more shared libraries (by short name, as passed to -l), from
# ${ACPP_<STEM>_DISCOVERED_ROOT}/<FACT> to ${ACPP_<STEM>_SUBDIR}/<FACT>,
# whole symlink chain preserved. FACT may be empty (the vendor root itself
# holds the library - libomp's shape).
#
# If the source directory already exists at configure time, resolution and
# the missing-file check happen now, so a broken SHIPPED configuration is a
# configure-time FATAL_ERROR ("shipped means it must be there") rather than
# a surprise at install time. If it does NOT exist yet - the one case this
# codebase has, toolchain-mode libomp, whose source is this same build's
# own not-yet-installed LLVM libdir (see cmake/install/*/common/omp.cmake)
# - resolution is deferred into the install(CODE) block itself, which runs
# at `cmake --install` time (after this component's own install has queued
# it), and fails there, clearly, if the vendor still is not present then.
function(acpp_install_vendor_libs)
  cmake_parse_arguments(_avl "" "STEM;FACT" "NAMES" ${ARGN})
  if(NOT ACPP_${_avl_STEM}_SHIPPED)
    return()
  endif()
  _acpp_vi_join_absolute(_avl_srcdir "${ACPP_${_avl_STEM}_DISCOVERED_ROOT}" "${_avl_FACT}")
  _acpp_vi_join_relative(_avl_destrel "${ACPP_${_avl_STEM}_SUBDIR}" "${_avl_FACT}")

  foreach(_avl_name IN LISTS _avl_NAMES)
    if(IS_DIRECTORY "${_avl_srcdir}")
      # Known now: fail fast at configure time, and record the exact
      # resolved filename(s) in the plan.
      _acpp_resolve_vendor_lib_files(_avl_files "${_avl_srcdir}" "${_avl_name}")
      if(NOT _avl_files)
        message(FATAL_ERROR
          "Vendor '${_avl_STEM}' is SHIPPED but library '${_avl_name}' was "
          "not found under ${_avl_srcdir} at configure time.")
      endif()
      foreach(_avl_f IN LISTS _avl_files)
        get_filename_component(_avl_fname "${_avl_f}" NAME)
        list(APPEND ACPP_VENDOR_INSTALL_PLAN "${_avl_destrel}/${_avl_fname}")
      endforeach()
    else()
      # Not known yet - the source directory itself does not exist at
      # configure time (toolchain-mode libomp; see
      # cmake/install/*/common/omp.cmake). Record what is sought, not a
      # resolved name, and let the install(CODE) block below resolve and
      # fail (clearly) at install time instead.
      list(APPEND ACPP_VENDOR_INSTALL_PLAN "${_avl_destrel}/ (deferred: ${_avl_name})")
    endif()
    if(NOT CMAKE_SCRIPT_MODE_FILE)
      install(CODE "include(\"${_ACPP_VENDOR_INSTALL_SELF}\")
_acpp_install_vendor_lib_now(\"${_avl_srcdir}\" \"\${CMAKE_INSTALL_PREFIX}/${_avl_destrel}\" \"${_avl_name}\")")
    endif()
  endforeach()
  set(ACPP_VENDOR_INSTALL_PLAN "${ACPP_VENDOR_INSTALL_PLAN}" PARENT_SCOPE)
endfunction()

# acpp_install_vendor_files(STEM <s> FACT <fact-or-empty>
#                           [FILES <files...>] [PROGRAMS <files...>])
#
# Plain files (FILES) and executables (PROGRAMS, installed with the
# executable bit set regardless of source permissions) from
# ${ACPP_<STEM>_DISCOVERED_ROOT}/<FACT> to ${ACPP_<STEM>_SUBDIR}/<FACT>.
# Source is expected to exist at configure time - every caller today names
# files under a vendor root discovery itself already validated - so a
# missing file is a FATAL_ERROR naming the vendor and path.
function(acpp_install_vendor_files)
  cmake_parse_arguments(_avf "" "STEM;FACT" "FILES;PROGRAMS" ${ARGN})
  if(NOT ACPP_${_avf_STEM}_SHIPPED)
    return()
  endif()
  _acpp_vi_join_absolute(_avf_srcdir "${ACPP_${_avf_STEM}_DISCOVERED_ROOT}" "${_avf_FACT}")
  _acpp_vi_join_relative(_avf_destrel "${ACPP_${_avf_STEM}_SUBDIR}" "${_avf_FACT}")

  foreach(_avf_kind FILES PROGRAMS)
    foreach(_avf_name IN LISTS _avf_${_avf_kind})
      set(_avf_src "${_avf_srcdir}/${_avf_name}")
      if(NOT EXISTS "${_avf_src}")
        message(FATAL_ERROR
          "Vendor '${_avf_STEM}' is SHIPPED but '${_avf_src}' was not "
          "found at configure time.")
      endif()
      list(APPEND ACPP_VENDOR_INSTALL_PLAN "${_avf_destrel}/${_avf_name}")
      if(NOT CMAKE_SCRIPT_MODE_FILE)
        if(_avf_kind STREQUAL "PROGRAMS")
          install(CODE "file(INSTALL \"${_avf_src}\" DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${_avf_destrel}\" TYPE PROGRAM)")
        else()
          install(CODE "file(INSTALL \"${_avf_src}\" DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${_avf_destrel}\" TYPE FILE)")
        endif()
      endif()
    endforeach()
  endforeach()
  set(ACPP_VENDOR_INSTALL_PLAN "${ACPP_VENDOR_INSTALL_PLAN}" PARENT_SCOPE)
endfunction()

# acpp_install_vendor_dir(STEM <s> FACT <fact-or-empty>)
#
# The whole directory ${ACPP_<STEM>_DISCOVERED_ROOT}/<FACT> (contents, not
# the directory entry itself), to ${ACPP_<STEM>_SUBDIR}/<FACT> - CUDA's
# include tree, for instance, where naming every header individually would
# be both unmaintainable and pointless (nothing there is toolchain-specific,
# it is the vendor's own public headers). Missing at configure time is a
# FATAL_ERROR, same reasoning as the other two helpers.
function(acpp_install_vendor_dir)
  cmake_parse_arguments(_avd "" "STEM;FACT" "" ${ARGN})
  if(NOT ACPP_${_avd_STEM}_SHIPPED)
    return()
  endif()
  _acpp_vi_join_absolute(_avd_srcdir "${ACPP_${_avd_STEM}_DISCOVERED_ROOT}" "${_avd_FACT}")
  _acpp_vi_join_relative(_avd_destrel "${ACPP_${_avd_STEM}_SUBDIR}" "${_avd_FACT}")
  if(NOT IS_DIRECTORY "${_avd_srcdir}")
    message(FATAL_ERROR
      "Vendor '${_avd_STEM}' is SHIPPED but directory '${_avd_srcdir}' was "
      "not found at configure time.")
  endif()
  list(APPEND ACPP_VENDOR_INSTALL_PLAN "${_avd_destrel}/")
  if(NOT CMAKE_SCRIPT_MODE_FILE)
    install(CODE "file(INSTALL \"${_avd_srcdir}/\" DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${_avd_destrel}\")")
  endif()
  set(ACPP_VENDOR_INSTALL_PLAN "${ACPP_VENDOR_INSTALL_PLAN}" PARENT_SCOPE)
endfunction()
