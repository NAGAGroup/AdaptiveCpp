# Core options - every platform and architecture.
#
# Core is everything not vendor-specific: the AdaptiveCpp runtime and common
# libraries, the LLVM toolchain we either build or depend on, the host JIT,
# and the driver's own behaviour.
#
# Include AFTER cmake/discovery.cmake, which runs every find_* up front. The
# values below read those results, so they are only correct once it has run.
#
# ---------------------------------------------------------------------------
# What is an option here, and what is not
# ---------------------------------------------------------------------------
#
# No FACTS are computed in this file. Where this build put our libraries, what
# LLVM's own library directory is, the versions - those go straight from their
# cmake variable into the configuration's @VAR@ stub, because nothing here
# chooses them.
#
# What is left divides in three.
#
#   * DEPLOY PATHS are the publisher's choice, made once at configure time.
#     They say where something lands in a deployed application, and because
#     our libraries are linked with a RUNPATH that has to reach them, they are
#     baked into binaries as well as written to the configuration. Discovery
#     never touches them: they describe a layout we are choosing, not a
#     machine we are inspecting.
#
#   * RESOURCE VALUES say where a particular thing is. Each has two sides -
#     what the driver uses when compiling, and what a deployed application's
#     JIT uses - because those are different facts: the driver runs from the
#     toolchain on a developer's machine, the JIT runs from the deployment on
#     someone else's.
#
#   * PROVENANCE VALUES say where the deploy step copies something from.
#     They have no application side: the libraries they name are reached
#     through DT_NEEDED linkage or the LLVM unit's own RUNPATH, so no running
#     application ever looks them up.
#
# A VENDOR unit (rule 3: assets we do not build) is steered at configure
# time by exactly two packager knobs: the find's own hints (CUDAToolkit_ROOT,
# LLVM_DIR, OpenCL_LIBRARY, WITH_*_BACKEND - never named here, they belong to
# discovery) and one install subdirectory, ACPP_<VENDOR>_SUBDIR. After
# discovery and that one knob, everything else about the vendor is derived:
# there is no per-resource -D override, in any strategy. A user of the
# installed toolchain can still override any entry through the environment,
# at the moment they use it - unchanged.
#
# What we build (rule 1) and, in plugin mode, the machine's own toolchain
# pieces (rule 2) are not vendor units at all: the strategy does not govern
# them. What we build always follows cmake's own install directories, in
# every strategy; the machine's own pieces are always absolute, in every
# strategy. See "Ownership" below.
#
# Guarded plain set(), never CACHE, for everything that is not itself a
# packager knob: an unguarded plain set() shadows a -D cache entry so the
# builder's value stops being read, and DEFINED is true for a cache entry as
# well, so the guard lets -D win.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A subdir is relative to the install root by construction. An absolute one,
# or one carrying the root itself, would stop being a pure subdirectory.
function(acpp_require_relative name)
  if(DEFINED ${name})
    if(IS_ABSOLUTE "${${name}}")
      message(FATAL_ERROR
        "${name} is a location inside a deployment and must be relative to "
        "its root.")
    endif()
    if("${${name}}" MATCHES "\\$ACPP_RT_LIB_DIR")
      message(FATAL_ERROR
        "${name} must not contain \$ACPP_RT_LIB_DIR; it is prepended where "
        "needed.")
    endif()
  endif()
endfunction()

# Discovery must have run before any options file. An unset input would
# otherwise expand empty, and a value built as "${prefix}/llc" would resolve
# to the root-level "/llc" - which no check on the resulting value can
# catch. find_* always sets its variable, empty or NOTFOUND when it found
# nothing, so an undefined input means discovery did not run at all.
function(acpp_require_discovered name)
  if(NOT DEFINED ${name})
    message(FATAL_ERROR
      "discovery variable ${name} is not set. cmake/discovery.cmake runs "
      "before the options files and exports every one of these, so an "
      "options file must never run without it.")
  endif()
endfunction()

# Compute the concrete relative path from the runtime library's own install
# directory to an install-root-relative path. This is the anchor every
# application-configuration value is written against: the runtime is what
# reads that configuration, and resolves its own directory before doing
# anything else with it (settings.cpp, dladdr on the library it is part of).
#
# Used only to build values written by configure_file - nothing resolves a
# {{ }} placeholder there the way a toolchain-side value's is resolved later,
# so unlike the toolchain side the result here must already be a concrete
# string, not a template.
function(acpp_relative_from_rt_libdir out_var target)
  if(WIN32)
    set(_acpp_rt_libdir "${CMAKE_INSTALL_BINDIR}")
  else()
    set(_acpp_rt_libdir "${CMAKE_INSTALL_LIBDIR}")
  endif()
  # file(RELATIVE_PATH) takes two absolute paths; neither needs to exist, so
  # any anchor shared by both sides works - it cancels out of the result.
  set(_acpp_anchor "/acpp-relative-path-anchor")
  file(RELATIVE_PATH _acpp_rel
    "${_acpp_anchor}/${_acpp_rt_libdir}"
    "${_acpp_anchor}/${target}")
  set(${out_var} "${_acpp_rel}" PARENT_SCOPE)
endfunction()

# Join relative path pieces with "/", dropping any that are empty (an
# install-at-root vendor subdir, a subdir fact discovery did not find) and
# never doubling or trailing a slash. All pieces are assumed relative
# already; nothing here preserves a leading "/" (see acpp_join_absolute for
# the discovered-root side, which must).
function(acpp_join_relative out_var)
  set(_acpp_pieces "")
  foreach(_acpp_piece IN LISTS ARGN)
    string(REGEX REPLACE "^/+|/+$" "" _acpp_piece "${_acpp_piece}")
    if(NOT "${_acpp_piece}" STREQUAL "")
      list(APPEND _acpp_pieces "${_acpp_piece}")
    endif()
  endforeach()
  list(LENGTH _acpp_pieces _acpp_n)
  if(_acpp_n EQUAL 0)
    set(${out_var} "" PARENT_SCOPE)
  else()
    string(JOIN "/" _acpp_joined ${_acpp_pieces})
    set(${out_var} "${_acpp_joined}" PARENT_SCOPE)
  endif()
endfunction()

# Join an absolute (or empty) discovered root with one relative piece,
# keeping the root's own absoluteness - the NOT SHIPPED side of a vendor's
# application value is the discovered location itself, not anything
# relative to our own tree. Empty in, empty out: nothing was discovered, so
# there is nothing to report (not an error).
function(acpp_join_absolute out_var root piece)
  if("${root}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()
  string(REGEX REPLACE "/+$" "" _acpp_root "${root}")
  string(REGEX REPLACE "^/+|/+$" "" _acpp_piece "${piece}")
  if("${_acpp_piece}" STREQUAL "")
    set(${out_var} "${_acpp_root}" PARENT_SCOPE)
  else()
    set(${out_var} "${_acpp_root}/${_acpp_piece}" PARENT_SCOPE)
  endif()
endfunction()

# ---------------------------------------------------------------------------
# Vendor units: shipped or not, two knobs either way
# ---------------------------------------------------------------------------
#
# Every vendor unit - cuda, nvhpc, hip, ocl, ze, vk, clspv, libomp, sleef,
# amath, svml/intlc, libnuma - gets exactly one packager knob beyond what
# its own discovery steers: ACPP_<VENDOR>_SUBDIR, a pure subdirectory with
# no root in it, resolved at configure time like CMAKE_INSTALL_LIBDIR
# itself, never deferred to a {{ }} placeholder. The default is
# <CMAKE_INSTALL_LIBDIR>/hipSYCL/ext/<lower> (Windows:
# CMAKE_INSTALL_BINDIR-based, matching where the rest of what we install
# already lands); an explicitly empty string installs straight at the root -
# the conda case, where the packager's own layout already scopes it.
#
# Whether a vendor is actually SHIPPED - copied into that subdirectory at
# all - is not a further knob; it falls straight out of the strategy and
# the vendor's own category (see "Controls" below): shipped under full,
# always; under full-permissive-only, only if the category is permissive;
# never under managed. Every other vendor-facing macro reads
# ACPP_<VENDOR>_SHIPPED, set here, to choose between the two shapes the
# per-vendor rule describes - relative to our own tree when shipped,
# the discovered location otherwise - rather than testing
# ACPP_DEPLOYMENT_STRATEGY itself.

# Whether a vendor unit of the given category ships under the strategy in
# effect. Sets _acpp_vendor_shipped in the caller's scope (a macro, not a
# function, precisely so that scope is the caller's and not thrown away).
macro(acpp_vendor_shipped category)
  if(NOT "${category}" MATCHES "^(permissive|nonpermissive)$")
    message(FATAL_ERROR
      "acpp_vendor_shipped: category must be permissive or nonpermissive, "
      "not '${category}'.")
  endif()
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "full")
    set(_acpp_vendor_shipped ON)
  elseif(ACPP_DEPLOYMENT_STRATEGY STREQUAL "full-permissive-only"
      AND "${category}" STREQUAL "permissive")
    set(_acpp_vendor_shipped ON)
  else()
    set(_acpp_vendor_shipped OFF)
  endif()
endmacro()

# Declare a vendor's install subdirectory knob and whether it ships.
# `category` is `permissive` or `nonpermissive` (see "Controls" for what
# that means and the gate it triggers). Replaces the old
# acpp_declare_vendor_subdir, which took no category because it never
# needed to decide shipped-ness itself - every strategy already treated
# every subdir as relative except the one absolute-path case the design
# walkthrough retired.
macro(acpp_declare_vendor stem lower category)
  if(NOT DEFINED ACPP_${stem}_SUBDIR)
    if(WIN32)
      set(ACPP_${stem}_SUBDIR "${CMAKE_INSTALL_BINDIR}/hipSYCL/ext/${lower}"
        CACHE STRING
        "Install subdirectory for the ${lower} vendor unit, relative to the install root. Empty installs straight at the root (e.g. a conda build).")
    else()
      set(ACPP_${stem}_SUBDIR "${CMAKE_INSTALL_LIBDIR}/hipSYCL/ext/${lower}"
        CACHE STRING
        "Install subdirectory for the ${lower} vendor unit, relative to the install root. Empty installs straight at the root (e.g. a conda build).")
    endif()
  endif()
  acpp_require_relative(ACPP_${stem}_SUBDIR)

  acpp_vendor_shipped(${category})
  set(ACPP_${stem}_SHIPPED ${_acpp_vendor_shipped})
  unset(_acpp_vendor_shipped)

  # Copying a nonpermissive vendor into our own install tree is the
  # redistribution decision the gate exists for (see "Controls"); a
  # packager choosing full-permissive-only never reaches this, because
  # ACPP_${stem}_SHIPPED is already OFF for a nonpermissive category there.
  if(ACPP_${stem}_SHIPPED
      AND "${category}" STREQUAL "nonpermissive"
      AND ACPP_DEPLOYMENT_STRATEGY STREQUAL "full"
      AND NOT ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN)
    message(FATAL_ERROR
      "Strategy full would ship the ${lower} vendor unit, which is "
      "nonpermissive, but ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN "
      "is OFF. Turn it on, having read ${lower}'s redistribution terms and "
      "accepted passing that obligation on to your own users, or configure "
      "with full-permissive-only instead, which ships permissive vendors "
      "only and needs no such decision.")
  endif()
endmacro()

# Declare "<lower>-install-root": where the driver finds the vendor. Also
# records the raw discovered root (ACPP_<stem>_DISCOVERED_ROOT), which the
# NOT SHIPPED side of every application-facing macro below reads directly -
# an application run against a not-shipped vendor uses the same absolute
# location the driver found, because nothing was copied anywhere else for
# it to use instead. Driver-only: nothing here is a two-sided resource,
# because the root by itself names no file an application reads; its
# subdirs (below) do that.
macro(acpp_declare_vendor_root stem lower discovered_var discovered)
  acpp_require_discovered(${discovered_var})
  set(ACPP_${stem}_DISCOVERED_ROOT "${discovered}")
  if(ACPP_${stem}_SHIPPED)
    set(ACPP_${stem}_INSTALL_ROOT "{{ acpp-root }}/{{ ${lower}-subdir }}")
  else()
    set(ACPP_${stem}_INSTALL_ROOT "${discovered}")
  endif()
endmacro()

# Declare one vendor-relative subdir fact, "<lower>-<x>-subdir": always the
# relative fact discovery found, in every strategy - it describes the
# vendor's own internal layout, not where we chose to put the vendor, so
# nothing here branches on shipped-ness. A link line composes this with the
# vendor root itself where an absolute answer is needed.
macro(acpp_declare_vendor_subdir_fact stem x discovered_var discovered)
  acpp_require_discovered(${discovered_var})
  set(ACPP_${stem}_${x}_SUBDIR "${discovered}")
endmacro()

# Declare the application-config value for one vendor subdir fact: what a
# deployed app's own configuration carries for this location. configure_file
# writes this literally - nothing resolves a {{ }} placeholder in it - so
# both branches must already be a concrete string.
#
# SHIPPED: the literal $ACPP_RT_LIB_DIR the runtime resolves at its own run
# time, plus the concrete path from the runtime library's install directory
# to the vendor subdir, plus this subdir fact - matching where the manifest's
# copy rows actually deploy the vendor.
#
# NOT SHIPPED: the discovered root joined with this subdir fact directly -
# an application run against a not-shipped vendor reaches the same absolute
# location the driver did, because nothing else was put anywhere for it.
macro(acpp_declare_vendor_app_dir stem lower x)
  if(ACPP_${stem}_SHIPPED)
    acpp_relative_from_rt_libdir(_acpp_vendor_app_rel "${ACPP_${stem}_SUBDIR}")
    acpp_join_relative(_acpp_vendor_app_rel
      "${_acpp_vendor_app_rel}" "${ACPP_${stem}_${x}_SUBDIR}")
    if("${_acpp_vendor_app_rel}" STREQUAL "")
      set(ACPP_APP_${stem}_${x}_DIR "\$ACPP_RT_LIB_DIR")
    else()
      set(ACPP_APP_${stem}_${x}_DIR "\$ACPP_RT_LIB_DIR/${_acpp_vendor_app_rel}")
    endif()
    unset(_acpp_vendor_app_rel)
  else()
    acpp_join_absolute(ACPP_APP_${stem}_${x}_DIR
      "${ACPP_${stem}_DISCOVERED_ROOT}" "${ACPP_${stem}_${x}_SUBDIR}")
  endif()
endmacro()

# The same, for a vendor unit with no internal breakdown - a single library
# with no separate lib/include/bin split (libomp, sleef, amath, svml/intlc,
# libnuma): its own install root is the whole answer, so there is no
# "<x>-subdir" to compose in. `lower` is unused in the SHIPPED/NOT SHIPPED
# bodies now that both sides are fully resolved cmake strings rather than
# {{ }} templates; it stays a parameter so every declare_* macro shares one
# call shape.
macro(acpp_declare_vendor_app_root stem lower)
  if(ACPP_${stem}_SHIPPED)
    acpp_relative_from_rt_libdir(_acpp_vendor_app_rel "${ACPP_${stem}_SUBDIR}")
    if("${_acpp_vendor_app_rel}" STREQUAL "")
      set(ACPP_APP_${stem}_INSTALL_ROOT "\$ACPP_RT_LIB_DIR")
    else()
      set(ACPP_APP_${stem}_INSTALL_ROOT "\$ACPP_RT_LIB_DIR/${_acpp_vendor_app_rel}")
    endif()
    unset(_acpp_vendor_app_rel)
  else()
    set(ACPP_APP_${stem}_INSTALL_ROOT "${ACPP_${stem}_DISCOVERED_ROOT}")
  endif()
endmacro()

# ---------------------------------------------------------------------------
# Ownership (rule: what we build is ours, what we don't in plugin mode is
# the machine's; only vendor plugins are governed by deployment strategy)
# ---------------------------------------------------------------------------
#
# Two more shapes than the vendor macros above, one for each side of the
# ownership rule. Neither reads ACPP_DEPLOYMENT_STRATEGY or a vendor's
# shipped-ness, and neither accepts a -D override through
# ACPP_TOOLCHAIN_*/ACPP_APP_*/the provenance variable itself: a strategy is
# a commitment about assets we do not build, and these entries name assets
# that are always ours to place or always the machine's to have, regardless
# of which strategy was chosen.

# Declare the two sides of a resource we build ourselves. Called only when
# the caller has already established this is our own build output (toolchain
# mode's LLVM pieces, or any platform's plugin-mode compiler plugin file):
# both sides are always the deploy-layout placeholder, in every strategy,
# because rule 1 says what we build is INSTALLED in every strategy. Whether
# it is also deployed with an application is a separate question the deploy
# helper answers, and it only exists under full - under managed, whatever
# channel the configurer uses to get their build to users is theirs, same
# as any ordinary CMake project's. `relative` must already be a concrete
# path (no {{ }}): the toolchain side still defers {{ acpp-root }} to the
# driver's own resolver, but the application side is written by
# configure_file, so it is computed here, from the runtime library's own
# install directory, the same way a vendor's SHIPPED value is.
macro(acpp_declare_owned_resource stem relative)
  set(ACPP_TOOLCHAIN_${stem} "{{ acpp-root }}/${relative}")
  acpp_relative_from_rt_libdir(_acpp_owned_rel "${relative}")
  if("${_acpp_owned_rel}" STREQUAL "")
    set(ACPP_APP_${stem} "\$ACPP_RT_LIB_DIR")
  else()
    set(ACPP_APP_${stem} "\$ACPP_RT_LIB_DIR/${_acpp_owned_rel}")
  endif()
  unset(_acpp_owned_rel)
endmacro()

# Declare a provenance entry for something we build ourselves: single-sided,
# same reasoning as acpp_declare_owned_resource. Still takes a {{ }} deploy
# path, unlike acpp_declare_owned_resource's now-concrete `relative`: a
# provenance entry has no application side needing a resolved path, only the
# toolchain side the driver's own resolver already handles.
macro(acpp_declare_owned_provenance var relative)
  set(${var} "{{ acpp-root }}/${relative}")
endmacro()

# Declare the two sides of a resource that belongs to the machine in plugin
# mode (rule 2): both sides are the discovered absolute path, in every
# strategy - nothing is deployed, so the JIT reaches the same machine copy
# the driver does. Empty when discovery found nothing (a profile that builds
# no plugin, decision d): that is not an error, it is the honest "this
# toolchain has no plugin, so it has no plugin-side compiler either".
# Override through the underlying find's own cache variable (upstream's
# CLANG_EXECUTABLE_PATH is one such CACHE STRING), never through
# ACPP_TOOLCHAIN_*/ACPP_APP_*: those names do not exist for a machine
# resource, because there is nothing here for a publisher to commit to.
macro(acpp_declare_machine_resource stem discovered_var discovered)
  acpp_require_discovered(${discovered_var})
  if("${${discovered_var}}" STREQUAL "" OR "${${discovered_var}}" MATCHES "-NOTFOUND$")
    set(ACPP_TOOLCHAIN_${stem} "")
    set(ACPP_APP_${stem} "")
  else()
    set(ACPP_TOOLCHAIN_${stem} "${discovered}")
    set(ACPP_APP_${stem} "${discovered}")
  endif()
endmacro()

# ---------------------------------------------------------------------------
# Controls
# ---------------------------------------------------------------------------
#
# The strategy decides two things and nothing more: whether a vendor's
# assets are ours to place (shipped) or the machine's own copy to use
# in-place (not shipped) - which decides the initial values written into
# the installed configuration - and whether `cmake --install` copies
# external assets into the tree at all. It says nothing about how a later
# deployment behaves - by then the configuration may have been edited or
# overridden.
#
# managed is the ordinary-CMake-project case: nothing is shipped, and
# whoever configures it sets rpaths etc. with standard CMake variables, as
# for any project - forcing a layout decision here, in every strategy, was
# the anti-pattern this replaced. full and full-permissive-only are where we
# take responsibility for vendor assets instead; they differ only in which
# vendors that covers (see the gate below).

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  set(ACPP_DEPLOYMENT_STRATEGY "managed")
endif()
if(NOT ACPP_DEPLOYMENT_STRATEGY MATCHES "^(managed|full-permissive-only|full)$")
  message(FATAL_ERROR
    "ACPP_DEPLOYMENT_STRATEGY must be one of managed, full-permissive-only "
    "or full, not '${ACPP_DEPLOYMENT_STRATEGY}'.")
endif()

# Copying NON-PERMISSIVE vendor assets into our own install tree is a
# redistribution decision. A packager setting this undertakes to have read the
# vendors' terms and to pass the obligation on to their own users; this
# comment is the one place they are guaranteed to pass on the way in.
#
# Permissive assets - LLVM itself - need no gate, which is why
# `full-permissive-only` exists: wanting a self-contained toolchain should not
# require opting into a legal decision you are not making.
if(NOT DEFINED ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN)
  set(ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN OFF)
endif()

# ---------------------------------------------------------------------------
# OMP: an ordinary vendor, in both build modes
# ---------------------------------------------------------------------------
#
# The OpenMP runtime our OMP backend links, and apps use, is a vendor unit
# like cuda or hip (principle 3 of the design walkthrough): governed by the
# strategy, with its own subdir, permissive. The build mode changes only the
# default SOURCE - which library the SHIPPED copy is taken from - not
# whether it is a vendor unit at all: in toolchain mode, the libomp of the
# LLVM this build produces (guaranteed to exist, since the product must
# work out of the box with only what we ship); in plugin mode, whatever
# find_package(OpenMP) found for the compiler AdaptiveCpp itself was built
# with (ACPP_DISCOVERED_LIBOMP_DIR, already computed either way).
#
# ACPP_LIBOMP_SOURCE_DIR is the one extra knob a vendor unit does not
# otherwise need: discovery cannot choose between libomp and libgomp, so a
# packager who wants GOMP instead points this here directly (libomp and
# GOMP are ABI-compatible) rather than fighting discovery's own hints.
# ACPP_LIBOMP_NAME is the short name (as passed to -l) of whichever library
# that directory holds, for wherever a link line or JIT setting composes it
# with a directory.
if(NOT DEFINED ACPP_LIBOMP_SOURCE_DIR)
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(ACPP_LIBOMP_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}"
      CACHE PATH
      "Where the OpenMP runtime shipped as the libomp vendor unit is taken from. Defaults to the libomp of the LLVM this build produces.")
  else()
    set(ACPP_LIBOMP_SOURCE_DIR "${ACPP_DISCOVERED_LIBOMP_DIR}"
      CACHE PATH
      "Where the OpenMP runtime shipped as the libomp vendor unit is taken from. Defaults to the libomp AdaptiveCpp itself was built against.")
  endif()
endif()
if(NOT DEFINED ACPP_LIBOMP_NAME)
  set(ACPP_LIBOMP_NAME "omp" CACHE STRING
    "The OpenMP runtime library's short name (as passed to -l), for whichever library ACPP_LIBOMP_SOURCE_DIR names. A packager pointing that at GOMP would set this to gomp.")
endif()

acpp_declare_vendor(LIBOMP libomp permissive)
acpp_declare_vendor_root(LIBOMP libomp ACPP_LIBOMP_SOURCE_DIR "${ACPP_LIBOMP_SOURCE_DIR}")

# NOT SHIPPED normally means "a machine asset, named by its absolute
# location" (acpp_declare_vendor_root's ordinary shape, kept above for
# plugin mode). But in toolchain mode, not-shipped libomp is still OURS -
# built by this same build, not discovered on some machine - so baking
# ACPP_LIBOMP_SOURCE_DIR's absolute ${CMAKE_INSTALL_PREFIX} into the
# toolchain config here would be wrong, for the same reason rule 1 keeps
# every owned resource's toolchain side a deploy-layout placeholder rather
# than a resolved path: the config has to keep meaning the same thing after the
# toolchain is copied or reinstalled elsewhere. The deploy-layout
# placeholder says the same thing those do - wherever this LLVM's own
# libdir ends up - without freezing today's prefix into it. The absolute
# ACPP_LIBOMP_SOURCE_DIR itself is still correct as-is for the root wiring
# commit's install rule, which needs a real path to copy the SHIPPED case
# from; only the not-shipped toolchain side is overridden here.
if(NOT ACPP_LIBOMP_SHIPPED AND LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_LIBOMP_INSTALL_ROOT "{{ acpp-root }}/{{ acpp-libdir }}")
endif()

# ---------------------------------------------------------------------------
# The host JIT
# ---------------------------------------------------------------------------
#
# Consumed by exactly one file, llvm-to-backend/host/LLVMToHost.cpp - not by
# the driver, not by the cmake package config, not by the PTX or AMDGPU
# backends. Hence jit-host-: these are narrower than the tools they are passed
# to, which the PTX backend also invokes. They name no location, so they have
# one value that travels unchanged.

if(NOT DEFINED ACPP_JIT_HOST_LLC_CPU_FLAG)
  set(ACPP_JIT_HOST_LLC_CPU_FLAG "-mcpu=native")
endif()
if(NOT DEFINED ACPP_JIT_HOST_OPT_CPU_FLAG)
  set(ACPP_JIT_HOST_OPT_CPU_FLAG "--mcpu=native")
endif()
if(NOT DEFINED ACPP_JIT_HOST_LLC_FLAGS)
  set(ACPP_JIT_HOST_LLC_FLAGS "")
endif()
if(NOT DEFINED ACPP_JIT_HOST_OPT_FLAGS)
  set(ACPP_JIT_HOST_OPT_FLAGS "")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-independent defaults
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_TARGETS)
  set(ACPP_TARGETS "${DEFAULT_TARGETS}")
endif()
if(NOT DEFINED ACPP_SEQUENTIAL_CXX_FLAGS)
  set(ACPP_SEQUENTIAL_CXX_FLAGS "")
endif()
if(NOT DEFINED ACPP_DRYRUN)
  set(ACPP_DRYRUN "false")
endif()
if(NOT DEFINED ACPP_SAVE_TEMPS)
  set(ACPP_SAVE_TEMPS "false")
endif()
if(NOT DEFINED ACPP_EXPLICIT_MULTIPASS)
  set(ACPP_EXPLICIT_MULTIPASS "false")
endif()
