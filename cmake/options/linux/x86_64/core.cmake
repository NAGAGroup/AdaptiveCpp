# Core options - linux, x86_64.
#
# Core is everything that is not vendor-specific: the AdaptiveCpp runtime and
# common libraries, the LLVM toolchain we either build or depend on, the host
# JIT, and the driver's own behaviour. Vendor-specific paths and flags live in
# the per-flow files beside this one.
#
# Every option here feeds exactly one toolchain configuration entry, whose
# source file carries @THIS_OPTION@ as its value and is filled by
# configure_file at install. Nothing else fills a configuration entry.
#
# Three rules govern every option:
#
#   * Guarded plain set(), never CACHE. An unguarded plain set() shadows a -D
#     cache entry so the builder's value stops being read; DEFINED is true for
#     a cache entry as well, so the guard lets -D win everywhere. Plain
#     variables also recompute on every configure, so flipping the deployment
#     strategy cannot leave a stale absolute path behind.
#
#   * The value rule: a builder's -D wins verbatim; otherwise, under the
#     `default` strategy, the discovered path when the corresponding find_*
#     found one; otherwise the declared default in placeholder form.
#
#   * Under any strategy that writes placeholders - bundled and both full*
#     modes - a -D path must be RELATIVE to the install root, and is rejected
#     if it is absolute. An absolute value there produces a toolchain that
#     claims to be relocatable and is not, discovered by whoever moves the
#     prefix. `default` is the strategy for absolute paths.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Reject an absolute -D under a placeholder-writing strategy.
function(acpp_require_relative name)
  if(DEFINED ${name} AND NOT ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    if(IS_ABSOLUTE "${${name}}")
      message(FATAL_ERROR
        "${name} must be relative to the install root under the "
        "${ACPP_DEPLOYMENT_STRATEGY} strategy - the toolchain would not be "
        "relocatable otherwise. Use the `default` strategy for absolute paths.")
    endif()
    if("${${name}}" MATCHES "\\$ACPP_PATH")
      message(FATAL_ERROR
        "${name} must not contain \$ACPP_PATH; it is prepended for you.")
    endif()
  endif()
endfunction()

# ---------------------------------------------------------------------------
# The deployment strategy, and the redistribution gate
# ---------------------------------------------------------------------------
#
# The strategy decides two things and nothing more: the initial values written
# into the installed toolchain configuration, and whether `cmake --install`
# copies external assets into the tree. It says nothing about how a later
# deployment behaves - by then the configuration may have been edited or
# overridden by environment variables.
#
#   default              absolute values; install copies nothing
#   bundled              placeholder values; install copies nothing
#   full-permissive-only placeholder values; install copies permissive assets
#   full                 placeholder values; install copies everything

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  set(ACPP_DEPLOYMENT_STRATEGY "default")
endif()
if(NOT ACPP_DEPLOYMENT_STRATEGY MATCHES "^(default|bundled|full-permissive-only|full)$")
  message(FATAL_ERROR
    "ACPP_DEPLOYMENT_STRATEGY must be one of default, bundled, "
    "full-permissive-only or full, not '${ACPP_DEPLOYMENT_STRATEGY}'.")
endif()

# Copying NON-PERMISSIVE vendor assets into our own install tree is a
# redistribution decision. NVIDIA's CUDA runtime is governed by the CUDA
# Toolkit EULA, Intel's SVML and Level Zero loader by their oneAPI
# redistribution terms. A packager setting this is undertaking to have read
# those terms and to pass the obligation on to their own users; this comment
# is the one place they are guaranteed to pass on the way in.
#
# Permissive assets - SLEEF, libnuma, LLVM itself - need no gate, which is
# why `full-permissive-only` exists: a packager who wants a self-contained
# toolchain should not have to opt into a legal decision they are not making.
if(NOT DEFINED ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN)
  set(ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN OFF)
endif()

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

# There is no vendor-zone option. Vendor libraries deploy beside our own,
# because that is the only place the backends' RUNPATH reaches: it is
# $ORIGIN/../, and the backends live in <libdir>/hipSYCL/. A zone under
# targets/<platform-arch>/ would require baking that subdirectory name into
# every binary at link time. See doc/vendor-library-linkage.md.

# The library directory a DEPLOYED application uses, relative to its own root.
# A preference, changeable after install.
acpp_require_relative(ACPP_LIBDIR)
if(NOT DEFINED ACPP_LIBDIR)
  set(ACPP_LIBDIR "${CMAKE_INSTALL_LIBDIR}")
endif()

# Where THIS toolchain put its own libraries - lib, lib64, whatever the
# distribution chose. A fact about the install, not a preference, which is why
# it has no environment variable: overriding where files already are is
# meaningless.
if(NOT DEFINED ACPP_TOOLCHAIN_LIBDIR)
  set(ACPP_TOOLCHAIN_LIBDIR "${CMAKE_INSTALL_LIBDIR}")
endif()

# Where deployed executables go. Upstream's convention is a private directory
# that does not clash with the install root's bin; conda packagers set this to
# "bin", where it is the same thing.
acpp_require_relative(ACPP_LIBEXEC_DIR)
if(NOT DEFINED ACPP_LIBEXEC_DIR)
  set(ACPP_LIBEXEC_DIR "hipSYCL/ext/bin")
endif()

# Where the deploy step writes application configurations under the `default`
# strategy, where nothing is copied and the application's tree holds none of
# our libraries. The default covers the common case - a user compiling for
# themselves - and a distribution maintainer building in `default` mode sets
# it to the system configuration directory instead.
#
# Deliberately NOT subject to acpp_require_relative: this is the one path that
# is meant to be absolute and to point outside the install tree. It concerns
# `default` deployments only, which make no relocatability claim.
if(NOT DEFINED ACPP_DEFAULT_STRATEGY_APP_CFG_DIR)
  set(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs")
endif()

# ---------------------------------------------------------------------------
# Provenance - read by the deploy step, never by an application
# ---------------------------------------------------------------------------
#
# These answer "where do I copy from", which is a different question from
# "what do I invoke". Separating them is what lets an exe entry be a bare name
# meaning "resolve on PATH" while full* still knows where the real binary is.

# The LLVM installation whose binaries full* copies.
acpp_require_relative(ACPP_LLVM_PATH)
if(NOT DEFINED ACPP_LLVM_PATH)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND LLVM_INSTALL_PREFIX)
    set(ACPP_LLVM_PATH "${LLVM_INSTALL_PREFIX}")
  else()
    set(ACPP_LLVM_PATH "{{ toolchain-path }}")
  endif()
endif()

# The three libraries resolved by the dynamic loader rather than by us. They
# get no deployed-as: an application never looks them up, the loader does.
# They exist here only so the deploy step knows where to copy them from.
#
# Under a placeholder strategy they name our own tree, because full* has
# already copied them there at install and deploy copies out of the tree.
# Only under `default`, where nothing was copied, do they name where the
# build found them.
acpp_require_relative(ACPP_LIBLLVM_PATH)
if(NOT DEFINED ACPP_LIBLLVM_PATH)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND LLVM_LIBRARY AND NOT LLVM_LIBRARY MATCHES "-NOTFOUND$")
    get_filename_component(ACPP_LIBLLVM_PATH "${LLVM_LIBRARY}" DIRECTORY)
  else()
    set(ACPP_LIBLLVM_PATH "{{ toolchain-path }}/{{ toolchain-libdir }}")
  endif()
endif()

acpp_require_relative(ACPP_LIBOMP_PATH)
if(NOT DEFINED ACPP_LIBOMP_PATH)
  set(acpp_found_libomp "")
  if(OpenMP_omp_LIBRARY)
    set(acpp_found_libomp "${OpenMP_omp_LIBRARY}")
  elseif(OpenMP_gomp_LIBRARY)
    set(acpp_found_libomp "${OpenMP_gomp_LIBRARY}")
  endif()
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND acpp_found_libomp)
    get_filename_component(ACPP_LIBOMP_PATH "${acpp_found_libomp}" DIRECTORY)
  else()
    set(ACPP_LIBOMP_PATH "{{ toolchain-path }}/{{ toolchain-libdir }}")
  endif()
endif()

acpp_require_relative(ACPP_LIBNUMA_PATH)
if(NOT DEFINED ACPP_LIBNUMA_PATH)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND NUMA_LIBRARY AND NOT NUMA_LIBRARY MATCHES "-NOTFOUND$")
    get_filename_component(ACPP_LIBNUMA_PATH "${NUMA_LIBRARY}" DIRECTORY)
  else()
    set(ACPP_LIBNUMA_PATH "{{ toolchain-path }}/{{ toolchain-libdir }}")
  endif()
endif()

# ---------------------------------------------------------------------------
# Compilers and executables - invocation, not provenance
# ---------------------------------------------------------------------------

# The DEVICE compiler, used by the multipass flows and by the generic JIT
# alike. Distinct from the host compiler below: this one compiles kernels.
acpp_require_relative(ACPP_CLANG_DEVICE_CMPLR)
  if(NOT DEFINED ACPP_CLANG_DEVICE_CMPLR)
  set(ACPP_CLANG_DEVICE_CMPLR "{{ llvm-path }}/bin/clang++")
endif()

# The HOST compiler the driver invokes for CPU code. May be gcc, or anything
# else with an OpenMP implementation - it does not have to be clang. Under
# `default` the build records what it was built with, so an existing
# standalone install keeps its behaviour.
acpp_require_relative(ACPP_CPU_CXX)
  if(NOT DEFINED ACPP_CPU_CXX)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND CMAKE_CXX_COMPILER)
    set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
  else()
    set(ACPP_CPU_CXX "{{ llvm-path }}/bin/clang++")
  endif()
endif()

# clang's own resource include directory.
acpp_require_relative(ACPP_CLANG_INCLUDE_PATH)
  if(NOT DEFINED ACPP_CLANG_INCLUDE_PATH)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND CLANG_INCLUDE_PATH AND NOT CLANG_INCLUDE_PATH MATCHES "-NOTFOUND$")
    set(ACPP_CLANG_INCLUDE_PATH "${CLANG_INCLUDE_PATH}")
  else()
    set(ACPP_CLANG_INCLUDE_PATH
        "{{ llvm-path }}/{{ toolchain-libdir }}/clang/{{ llvm-version-major }}/include")
  endif()
endif()

# The LLVM executables the JIT invokes while an application runs. Each may be
# a bare name, in which case the platform resolves it on PATH - which is what
# a toolchain that does not ship its own LLVM wants. The platform's executable
# suffix does not appear: this file is the linux one.
acpp_require_relative(ACPP_LLC)
  if(NOT DEFINED ACPP_LLC)
  set(ACPP_LLC "{{ llvm-path }}/bin/llc")
endif()
acpp_require_relative(ACPP_OPT)
  if(NOT DEFINED ACPP_OPT)
  set(ACPP_OPT "{{ llvm-path }}/bin/opt")
endif()
acpp_require_relative(ACPP_LLD)
  if(NOT DEFINED ACPP_LLD)
  set(ACPP_LLD "{{ llvm-path }}/bin/ld.lld")
endif()
acpp_require_relative(ACPP_LLVMSPIRV)
  if(NOT DEFINED ACPP_LLVMSPIRV)
  set(ACPP_LLVMSPIRV "{{ llvm-path }}/bin/llvm-spirv")
endif()

# The compiler plugin, in plugin builds only. When AdaptiveCpp is linked into
# the LLVM tools there is no plugin file and the driver emits no plugin flags.
# The driver currently hardcodes "lib" when building this path, which is wrong
# on any lib64 distribution; this entry is what those sites should read.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  acpp_require_relative(ACPP_PLUGIN_PATH)
  if(NOT DEFINED ACPP_PLUGIN_PATH)
    set(ACPP_PLUGIN_PATH "{{ toolchain-path }}/{{ toolchain-libdir }}/libacpp-clang.so")
  endif()
endif()

# ---------------------------------------------------------------------------
# The host JIT
# ---------------------------------------------------------------------------
#
# Consumed by exactly one file, src/compiler/llvm-to-backend/host/LLVMToHost.cpp
# - not by the driver, not by the cmake package config, not by the PTX or
# AMDGPU backends. Hence the jit-host- prefix: these are narrower than the
# tools they are passed to, which the PTX backend also invokes.

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

# Which vector math library the host JIT uses. NOT discovery-derived: several
# may be present at once and discovery cannot choose between them. The default
# is the one every glibc system has, and every vector math code path compiles
# unconditionally, so changing this in an installed configuration - or in a
# deployed application's - is all that is needed. The runtime falls back to
# libmvec when the configured library is absent.
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "libmvec")
endif()

# One directory per library. The library's short name is written into the
# JIT's link invocation, so only the directory needs resolving. libmvec needs
# no entry: the only correct copy is the one the loader resolves in the
# running process.
foreach(acpp_vml IN ITEMS SLEEF AMATH SVML)
  acpp_require_relative(ACPP_${acpp_vml}_DIR)
  if(NOT DEFINED ACPP_${acpp_vml}_DIR)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND LIB${acpp_vml} AND NOT LIB${acpp_vml} MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_${acpp_vml}_DIR "${LIB${acpp_vml}}" DIRECTORY)
    else()
      set(ACPP_${acpp_vml}_DIR "{{ toolchain-path }}/{{ toolchain-libdir }}")
    endif()
  endif()
endforeach()

# ---------------------------------------------------------------------------
# Driver behaviour
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_TARGETS)
  set(ACPP_TARGETS "${DEFAULT_TARGETS}")
endif()
if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "")
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
