# Discovery - every find_* the core options file reads, run up front.
#
# The options files describe the configuration; this file describes the
# machine and the build. It runs before any options file and exports one
# variable per input the options declare: acpp_require_discovered() in the
# options files makes an undefined input a configure error, because find_*
# always sets its variable, so an unset one can only mean discovery did not
# run.
#
# Every export is named ACPP_DISCOVERED_*: the namespace is ours, so nothing
# else can collide with it. This matters in the linked build in particular -
# the parent LLVM build's own variables (LLVM_TOOLS_BINARY_DIR,
# CLANG_EXECUTABLE_PATH) hold BUILD-tree locations the build itself still
# uses, and the configuration needs INSTALL-tree facts.
#
# AdaptiveCpp comes in two shapes, and this file has a half for each:
#
#   * linked into an LLVM toolchain we build - there is nothing to find:
#     the parent build is the discovery, and every LLVM location derives
#     from its install prefix.
#   * a plugin added to an existing LLVM - find_package(LLVM CONFIG) and
#     the clang searches.
#
# Machine-level libraries (libomp, libnuma, the vector math libraries) are
# found in both modes. Backend-specific discovery (CUDA, ROCm, OpenCL,
# Level Zero, clspv, nvc++) is not here: it loads from
# cmake/discovery/<backend>.cmake alongside the flow that needs it.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# The mode
# ---------------------------------------------------------------------------

# The root sets ACPP_LLVM_COMPONENT when this tree is built as part of an
# LLVM build. A component build that does not link the plugin into the tools
# is a third shape - a separately loaded plugin inside an LLVM we also build
# - which nothing qualifies and nothing here pretends to describe.
if(ACPP_LLVM_COMPONENT AND NOT LLVM_ADAPTIVECPP_LINK_IN_TOOLS)
  message(FATAL_ERROR
    "Building AdaptiveCpp as an LLVM component without "
    "LLVM_ADAPTIVECPP_LINK_IN_TOOLS is not supported. The linked build is "
    "one toolchain with one clang; a separately loaded plugin inside an LLVM "
    "we also build is a different toolchain, and this tree does not qualify "
    "it.")
endif()

if(ACPP_LLVM_COMPONENT)
  # -------------------------------------------------------------------------
  # Linked: derive from the parent build's install prefix
  # -------------------------------------------------------------------------
  # The parent installs everything into one prefix - LLVM's tools and
  # libraries, its libomp, and AdaptiveCpp itself - which is why
  # llvm-deploy-path defaults to "." and every placeholder built on it names
  # the toolchain root.

  set(ACPP_DISCOVERED_LLVM_PREFIX "${CMAKE_INSTALL_PREFIX}")
  set(ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_PREFIX}/bin")
  # LLVM's library directory relative to its prefix. A single segment
  # everywhere we build ("lib"); kept a path so a multiarch layout would
  # still read correctly in the entries that reference it.
  set(ACPP_DISCOVERED_LLVM_LIBDIR "lib${LLVM_LIBDIR_SUFFIX}")
  set(ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_LLVM_BINDIR}/clang++")
  # clang's resource directory, from LLVM's own module - it honours a
  # builder's CLANG_RESOURCE_DIR override, which the stock formula does not.
  include(GetClangResourceDir)
  get_clang_resource_dir(_acpp_clang_resource_dir
    PREFIX "${ACPP_DISCOVERED_LLVM_PREFIX}" SUBDIR include)
  set(ACPP_DISCOVERED_CLANG_INCLUDE "${_acpp_clang_resource_dir}")

  # The parent builds libomp with the toolchain (LLVM_ENABLE_PROJECTS
  # includes openmp) and installs it into the prefix's library directory.
  set(ACPP_DISCOVERED_LIBOMP_DIR
    "${ACPP_DISCOVERED_LLVM_PREFIX}/${ACPP_DISCOVERED_LLVM_LIBDIR}")
else()
  # -------------------------------------------------------------------------
  # Plugin: find the LLVM this toolchain plugs into
  # -------------------------------------------------------------------------
  # LLVM_DIR must name an INSTALLED LLVM's cmake export. A config exported
  # from a build tree answers with build-tree locations, which are not
  # install-time facts.

  set(_acpp_llvm_dir_old "${LLVM_DIR}")
  find_package(LLVM CONFIG REQUIRED)
  if(_acpp_llvm_dir_old AND NOT "${_acpp_llvm_dir_old}" STREQUAL "${LLVM_DIR}")
    message(WARNING
      "Could not find LLVM in the requested location LLVM_DIR=${_acpp_llvm_dir_old}; using ${LLVM_DIR}.")
  endif()

  set(ACPP_DISCOVERED_LLVM_BINDIR "${LLVM_TOOLS_BINARY_DIR}")
  get_filename_component(ACPP_DISCOVERED_LLVM_PREFIX
    "${ACPP_DISCOVERED_LLVM_BINDIR}" DIRECTORY)
  if(NOT ACPP_DISCOVERED_LLVM_PREFIX OR ACPP_DISCOVERED_LLVM_PREFIX STREQUAL "/")
    message(FATAL_ERROR
      "LLVM_TOOLS_BINARY_DIR ('${LLVM_TOOLS_BINARY_DIR}') does not look like "
      "an installed LLVM's bin directory; is LLVM_DIR pointing at a build "
      "tree?")
  endif()

  file(RELATIVE_PATH ACPP_DISCOVERED_LLVM_LIBDIR
    "${ACPP_DISCOVERED_LLVM_PREFIX}" "${LLVM_LIBRARY_DIRS}")
  if(ACPP_DISCOVERED_LLVM_LIBDIR STREQUAL "")
    message(FATAL_ERROR
      "LLVM_LIBRARY_DIRS ('${LLVM_LIBRARY_DIRS}') is not inside the LLVM "
      "prefix ('${ACPP_DISCOVERED_LLVM_PREFIX}').")
  endif()

  find_path(CLANG_AST_HEADER_DIR NAMES clang/AST/ASTContext.h
    PATHS ${LLVM_INCLUDE_DIRS})
  if(NOT CLANG_AST_HEADER_DIR)
    message(WARNING
      "AdaptiveCpp requires clang development headers, but they were not "
      "found.\n"
      "You might need to install the clang development package "
      "(e.g. libclang-dev).")
  endif()

  # The device compiler: versioned name first, then the LLVM bin directory,
  # then PATH.
  find_program(ACPP_DISCOVERED_CLANG
    NAMES clang++-${LLVM_VERSION_MAJOR}
          clang++-${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}
          clang++
    HINTS ${ACPP_DISCOVERED_LLVM_BINDIR})
  if(NOT ACPP_DISCOVERED_CLANG OR ACPP_DISCOVERED_CLANG MATCHES "-NOTFOUND$")
    message(SEND_ERROR "Could not find clang executable")
  endif()

  # clang's resource directory - the JIT's HIP compilation reads it. An
  # installed LLVM that placed it elsewhere (CLANG_RESOURCE_DIR at its
  # build) is not discoverable from its cmake exports; the escape hatch is
  # the clang-include-path environment variable.
  find_path(ACPP_DISCOVERED_CLANG_INCLUDE __clang_cuda_runtime_wrapper.h
    HINTS
      ${ACPP_DISCOVERED_LLVM_PREFIX}/${ACPP_DISCOVERED_LLVM_LIBDIR}/clang/${LLVM_VERSION_MAJOR}/include
      ${ACPP_DISCOVERED_LLVM_PREFIX}/lib64/clang/${LLVM_VERSION_MAJOR}/include
      ${ACPP_DISCOVERED_LLVM_PREFIX}/lib/clang/${LLVM_VERSION_MAJOR}/include)
  if(NOT ACPP_DISCOVERED_CLANG_INCLUDE)
    message(SEND_ERROR
      "clang's resource include directory was not found under the LLVM "
      "prefix ${ACPP_DISCOVERED_LLVM_PREFIX}. The JIT's HIP compilation "
      "needs it; install clang's resource files or point discovery at an "
      "LLVM that carries them.")
  endif()

  # libomp: whatever this toolchain links against. FindOpenMP answers for
  # the compiler in use; when the runtime is ambient - gomp beside gcc, in
  # the system directories or inside a conda env - it reports a flag and no
  # path, and empty is the honest answer: the platform provides it.
  find_package(OpenMP QUIET COMPONENTS CXX)
  set(ACPP_DISCOVERED_LIBOMP_DIR "")
  foreach(_acpp_omp_lib IN LISTS OpenMP_CXX_LIBRARIES)
    if(EXISTS "${_acpp_omp_lib}")
      get_filename_component(ACPP_DISCOVERED_LIBOMP_DIR "${_acpp_omp_lib}" DIRECTORY)
      break()
    endif()
  endforeach()
endif()

# ---------------------------------------------------------------------------
# Machine-level libraries - both modes
# ---------------------------------------------------------------------------
# The find variable names match the ones the subdirectories already use
# (NUMA_LIBRARY, LIBSLEEF, ...), so their own find_* calls become cache
# hits. Not found is a valid state for every one of these: the exported
# directory is empty, the entries go to their placeholder shape, and the
# manifest rows are skipped at deploy.

# libnuma: an ordinary shared library beside our own, reached through
# DT_NEEDED linkage.
find_path(NUMA_INCLUDE_DIR NAMES numa.h)
find_library(NUMA_LIBRARY NAMES numa)
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
if(NUMA_LIBRARY AND NOT NUMA_LIBRARY MATCHES "-NOTFOUND$")
  get_filename_component(ACPP_DISCOVERED_LIBNUMA_DIR "${NUMA_LIBRARY}" DIRECTORY)
endif()

# The vector math libraries. Unconditional on purpose: a machine that has
# one simply has it, and the JIT chooses between them when an application
# runs. intlc is found because it deploys beside svml, but it has no entry
# of its own.
find_library(LIBSLEEF NAMES sleefgnuabi)
find_library(LIBAMATH NAMES amath)
find_library(LIBSVML NAMES svml)
find_library(LIBINTLC NAMES intlc)

set(ACPP_DISCOVERED_SLEEF_DIR "")
if(LIBSLEEF AND NOT LIBSLEEF MATCHES "-NOTFOUND$")
  get_filename_component(ACPP_DISCOVERED_SLEEF_DIR "${LIBSLEEF}" DIRECTORY)
endif()
set(ACPP_DISCOVERED_AMATH_DIR "")
if(LIBAMATH AND NOT LIBAMATH MATCHES "-NOTFOUND$")
  get_filename_component(ACPP_DISCOVERED_AMATH_DIR "${LIBAMATH}" DIRECTORY)
endif()
set(ACPP_DISCOVERED_SVML_DIR "")
if(LIBSVML AND NOT LIBSVML MATCHES "-NOTFOUND$")
  get_filename_component(ACPP_DISCOVERED_SVML_DIR "${LIBSVML}" DIRECTORY)
endif()
