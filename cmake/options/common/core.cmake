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
# A resource value is builder-overridable ONLY under `default`. Choosing any
# other strategy is a commitment that this toolchain package contains what it
# needs, so its paths follow from the deploy layout rather than being set one
# at a time. Users of the installed toolchain can still override any of them
# through the environment, at the moment they use it.
#
# Guarded plain set(), never CACHE: an unguarded plain set() shadows a -D
# cache entry so the builder's value stops being read, and DEFINED is true for
# a cache entry as well, so the guard lets -D win.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A deploy path is relative to the install root by construction. An absolute
# one would produce a toolchain that claims to be relocatable and is not.
function(acpp_require_relative name)
  if(DEFINED ${name})
    if(IS_ABSOLUTE "${${name}}")
      message(FATAL_ERROR
        "${name} is a location inside a deployment and must be relative to "
        "its root.")
    endif()
    if("${${name}}" MATCHES "\\$ACPP_PATH")
      message(FATAL_ERROR
        "${name} must not contain \$ACPP_PATH; it is prepended where needed.")
    endif()
  endif()
endfunction()

# Refuse a resource value outside `default`, and say where the real knob is.
function(acpp_default_strategy_only name)
  if(DEFINED ${name} AND NOT ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    message(FATAL_ERROR
      "-D${name} is only accepted under the `default` deployment strategy.\n"
      "Choosing ${ACPP_DEPLOYMENT_STRATEGY} is a commitment that this "
      "toolchain package contains what it needs, so individual paths follow "
      "from the deploy layout - set ACPP_LLVM_DEPLOY_PATH or "
      "ACPP_LIBOMP_DEPLOY_PATH instead.\n"
      "A user of the installed toolchain can still override this through its "
      "environment variable.")
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
# they are the same relative location seen from two roots - the toolchain's
# when driving, the deployment's when running.
#
# `discovered_var` names the discovery variable the value came from - for the
# LLVM executables that is the tools directory, and `discovered` joins the
# file name onto its value.
macro(acpp_declare_resource stem discovered_var discovered relative)
  acpp_require_discovered(${discovered_var})
  acpp_default_strategy_only(ACPP_TOOLCHAIN_${stem})
  acpp_default_strategy_only(ACPP_APP_${stem})
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND NOT "${discovered}" STREQUAL ""
      AND NOT "${discovered}" MATCHES "-NOTFOUND$")
    if(NOT DEFINED ACPP_TOOLCHAIN_${stem})
      set(ACPP_TOOLCHAIN_${stem} "${discovered}")
    endif()
    if(NOT DEFINED ACPP_APP_${stem})
      set(ACPP_APP_${stem} "${discovered}")
    endif()
  else()
    if(NOT DEFINED ACPP_TOOLCHAIN_${stem})
      set(ACPP_TOOLCHAIN_${stem} "{{ toolchain-path }}/${relative}")
    endif()
    if(NOT DEFINED ACPP_APP_${stem})
      # \$ so cmake does not try to read $ACPP_PATH/{{ ... }} as a variable
      # reference; the written value is a literal $ACPP_PATH.
      set(ACPP_APP_${stem} "\$ACPP_PATH/${relative}")
    endif()
  endif()
endmacro()

# Declare a provenance resource: where the deploy step copies something from.
# Single-sided by construction - no application ever reads these, so there is
# no application-side value to compute. The discovery-variable rule is the
# same as acpp_declare_resource's.
macro(acpp_declare_provenance var discovered_var discovered relative)
  acpp_require_discovered(${discovered_var})
  acpp_default_strategy_only(${var})
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND NOT "${discovered}" STREQUAL ""
      AND NOT "${discovered}" MATCHES "-NOTFOUND$")
    if(NOT DEFINED ${var})
      set(${var} "${discovered}")
    endif()
  else()
    if(NOT DEFINED ${var})
      set(${var} "{{ toolchain-path }}/${relative}")
    endif()
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
