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
    if("${${name}}" MATCHES "\\$ACPP_RUNTIME_ROOT")
      message(FATAL_ERROR
        "${name} must not contain \$ACPP_RUNTIME_ROOT; it is prepended "
        "where needed.")
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

# Declare the two sides of one resource.
#
# Under `default` both are the discovered absolute path: nothing is deployed,
# so an application uses the toolchain's own copy. Under the other strategies
# they are the same relative location seen from two roots - {{ acpp-root }}
# when the driver is compiling, from the toolchain; the literal
# $ACPP_RUNTIME_ROOT the C++ runtime resolves at its own run time, from
# wherever the deployment has ended up.
#
# `discovered_var` names the discovery variable the value came from - for the
# LLVM executables that is the tools directory, and `discovered` joins the
# file name onto its value. No -D override of the result exists; see the
# file header.
macro(acpp_declare_resource stem discovered_var discovered relative)
  acpp_require_discovered(${discovered_var})
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND NOT "${discovered}" STREQUAL ""
      AND NOT "${discovered}" MATCHES "-NOTFOUND$")
    set(ACPP_TOOLCHAIN_${stem} "${discovered}")
    set(ACPP_APP_${stem} "${discovered}")
  else()
    set(ACPP_TOOLCHAIN_${stem} "{{ acpp-root }}/${relative}")
    # \$ so cmake does not try to read $ACPP_RUNTIME_ROOT/{{ ... }} as a
    # variable reference; the written value is a literal $ACPP_RUNTIME_ROOT.
    set(ACPP_APP_${stem} "\$ACPP_RUNTIME_ROOT/${relative}")
  endif()
endmacro()

# Declare a provenance resource: where the deploy step copies something from.
# Single-sided by construction - no application ever reads these, so there is
# no application-side value to compute. The discovery-variable rule is the
# same as acpp_declare_resource's.
#
# This macro is for VENDOR resources only (rule 3): assets we do not build.
# What we build (rule 1) and what belongs to the machine in plugin mode
# (rule 2) use acpp_declare_owned_resource / acpp_declare_owned_provenance
# and acpp_declare_machine_resource below instead - ownership, not the
# deployment strategy, decides those.
macro(acpp_declare_provenance var discovered_var discovered relative)
  acpp_require_discovered(${discovered_var})
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND NOT "${discovered}" STREQUAL ""
      AND NOT "${discovered}" MATCHES "-NOTFOUND$")
    set(${var} "${discovered}")
  else()
    set(${var} "{{ acpp-root }}/${relative}")
  endif()
endmacro()

# ---------------------------------------------------------------------------
# Vendor units: two knobs, everything else derived
# ---------------------------------------------------------------------------
#
# Every vendor unit - cuda, nvhpc, hip, ocl, ze, vk, clspv, and the
# vendor-plugin libraries (libomp in plugin mode, sleef, amath, svml/intlc,
# libnuma) - gets exactly one packager knob beyond what its own discovery
# steers: ACPP_<STEM>_SUBDIR, a pure subdirectory with no root in it,
# resolved at configure time like CMAKE_INSTALL_LIBDIR itself, never
# deferred to a {{ }} placeholder. The default is
# <CMAKE_INSTALL_LIBDIR>/hipSYCL/ext/<lower> (Windows:
# CMAKE_INSTALL_BINDIR-based, matching where the rest of what we install
# already lands); an explicitly empty string installs straight at the root -
# the conda case, where the packager's own layout already scopes it.

macro(acpp_declare_vendor_subdir stem lower)
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
endmacro()

# Declare "<lower>-install-root": where the driver finds the vendor. Under
# `default`, the discovered absolute prefix. Under managed/full, identical
# in both - {{ acpp-root }}/{{ <lower>-subdir }} - because `managed` differs
# from `full` only in whether cmake copies the vendor in, never in what the
# driver is told to expect. Driver-only: nothing here is a two-sided
# resource, because the root by itself names no file an application reads;
# its subdirs (below) do that.
macro(acpp_declare_vendor_root stem lower discovered_var discovered)
  acpp_require_discovered(${discovered_var})
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    set(ACPP_${stem}_INSTALL_ROOT "${discovered}")
  else()
    set(ACPP_${stem}_INSTALL_ROOT "{{ acpp-root }}/{{ ${lower}-subdir }}")
  endif()
endmacro()

# Declare one vendor-relative subdir fact, "<lower>-<x>-subdir": always the
# relative fact discovery found, in every strategy - it describes the
# vendor's own internal layout, not where we chose to put the vendor, so
# nothing here branches on ACPP_DEPLOYMENT_STRATEGY. A link line composes
# this with the vendor root itself where an absolute answer is needed.
macro(acpp_declare_vendor_subdir_fact stem x discovered_var discovered)
  acpp_require_discovered(${discovered_var})
  set(ACPP_${stem}_${x}_SUBDIR "${discovered}")
endmacro()

# Declare the application-config value for one vendor subdir fact (D7): what
# a deployed app's own configuration carries for this location. Under
# `default` the application runs against the same discovered vendor install
# the driver found, so the value already resolves absolute via the driver's
# own {{ }} entries. Otherwise it is composed from the literal
# $ACPP_RUNTIME_ROOT the C++ runtime resolves at its own run time, matching
# where the manifest's copy rows actually deploy the vendor.
macro(acpp_declare_vendor_app_subdir stem lower x)
  string(TOLOWER "${x}" _acpp_vendor_app_subdir_x)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    set(ACPP_APP_${stem}_${x}_SUBDIR
      "{{ ${lower}-install-root }}/{{ ${lower}-${_acpp_vendor_app_subdir_x}-subdir }}")
  else()
    set(ACPP_APP_${stem}_${x}_SUBDIR
      "\$ACPP_RUNTIME_ROOT/{{ ${lower}-subdir }}/{{ ${lower}-${_acpp_vendor_app_subdir_x}-subdir }}")
  endif()
  unset(_acpp_vendor_app_subdir_x)
endmacro()

# The same, for a vendor unit with no internal breakdown - a single library
# with no separate lib/include/bin split (libomp in plugin mode, sleef,
# amath, svml/intlc, libnuma): its own install root is the whole answer, so
# there is no "<x>-subdir" to compose in.
macro(acpp_declare_vendor_app_root stem lower)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    set(ACPP_APP_${stem}_INSTALL_ROOT "{{ ${lower}-install-root }}")
  else()
    set(ACPP_APP_${stem}_INSTALL_ROOT "\$ACPP_RUNTIME_ROOT/{{ ${lower}-subdir }}")
  endif()
endmacro()

# ---------------------------------------------------------------------------
# Ownership (rule: what we build is ours, what we don't in plugin mode is
# the machine's; only vendor plugins are governed by deployment strategy)
# ---------------------------------------------------------------------------
#
# Two more shapes than acpp_declare_resource/acpp_declare_provenance, one for
# each side of the ownership rule. Neither reads ACPP_DEPLOYMENT_STRATEGY,
# and neither accepts a -D override through ACPP_TOOLCHAIN_*/ACPP_APP_*/the
# provenance variable itself: a strategy is a commitment about assets we do
# not build, and these entries name assets that are always ours to place or
# always the machine's to have, regardless of which strategy was chosen.

# Declare the two sides of a resource we build ourselves. Called only when
# the caller has already established this is our own build output (toolchain
# mode's LLVM pieces, or any platform's plugin-mode compiler plugin file):
# both sides are always the deploy-layout placeholder, in every strategy
# including `default`, because rule 1 says what we build is installed and
# deployed with apps in every strategy. What we build follows cmake's own
# install directories under {{ acpp-root }} - there is no separate deploy-path
# knob for it, and no override for the resource value itself.
macro(acpp_declare_owned_resource stem relative)
  set(ACPP_TOOLCHAIN_${stem} "{{ acpp-root }}/${relative}")
  # \$ so cmake does not try to read $ACPP_RUNTIME_ROOT/{{ ... }} as a
  # variable reference; the written value is a literal $ACPP_RUNTIME_ROOT.
  set(ACPP_APP_${stem} "\$ACPP_RUNTIME_ROOT/${relative}")
endmacro()

# Declare a provenance entry for something we build ourselves: single-sided,
# same reasoning as acpp_declare_owned_resource.
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
# The strategy decides two things and nothing more: the initial values written
# into the installed configuration, and whether `cmake --install` copies
# external assets into the tree. It says nothing about how a later deployment
# behaves - by then the configuration may have been edited or overridden.

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  set(ACPP_DEPLOYMENT_STRATEGY "default")
endif()
if(NOT ACPP_DEPLOYMENT_STRATEGY MATCHES "^(default|managed|full-permissive-only|full)$")
  message(FATAL_ERROR
    "ACPP_DEPLOYMENT_STRATEGY must be one of default, managed, "
    "full-permissive-only or full, not '${ACPP_DEPLOYMENT_STRATEGY}'.")
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
