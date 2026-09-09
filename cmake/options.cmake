# AdaptiveCpp configuration options.
#
# Every path AdaptiveCpp resolves is declared here, once. This file is both the
# implementation and the documentation: if an option is not in this file it does
# not exist, and a reader should never have to search the cmake tree to find out
# what is configurable or what a setting does.
#
# See doc/relocatable-overhaul-spec.md for the normative rules. In short:
#
#   * No path is compiled into a binary. These options decide what gets written
#     into the toolchain configuration file, which is text and can be corrected
#     without a rebuild.
#   * An option exists only for something that can live OUTSIDE our install
#     tree. Anything we ship - our bitcode, the SPIR-V translator, the Level
#     Zero and OpenCL loaders - is found relative to our own libraries, and a
#     knob for it could only ever configure a wrong answer.
#   * One name serves every surface. The cmake option, the environment variable
#     and the configuration key are the same string, because the configuration
#     file format is `<environment-variable>=<value>`.
#
# The three states a setting can be read in are named exactly as the
# specification names them, and never abbreviated:
#
#   building   when building the toolchain    (cmake; this file)
#   driving    when driving the toolchain     (the acpp driver sets flags)
#   running    when running an application    (loaders and the JIT)
#
# STATES is not decoration. The application configuration file is derived from
# the toolchain one by taking every option marked `running`, so a missing or
# wrong value here becomes a missing or wrong value on a user's machine.

include_guard(GLOBAL)

set(ACPP_DECLARED_OPTIONS "" CACHE INTERNAL "Every option declared by options.cmake")

# acpp_option(NAME <var> TYPE <PATH|FILEPATH|STRING> STATES <states...>
#             [BACKEND <name>] [DEFAULT_FROM <var>] [RELATIVE <path>] DOC <text>)
#
#   NAME         the option, the environment variable, and the config key
#   TYPE         cmake cache type
#   STATES       any of: building driving running
#   BACKEND      only declared when that backend is enabled; omit for core
#   DEFAULT_FROM the variable holding the discovered value, normally a find_*
#                result. Kept outside this file so discovery logic stays where
#                it belongs and this file stays declarative.
#   RELATIVE     location under the install root, used when the build is
#                configured to be relocatable. Omit for resources that are not
#                ours to place.
#   DOC          one line, shown in the cache and in the generated table
function(acpp_option)
  set(one_value NAME TYPE BACKEND DEFAULT_FROM RELATIVE DOC)
  set(multi_value STATES)
  cmake_parse_arguments(OPT "" "${one_value}" "${multi_value}" ${ARGN})

  if(NOT OPT_NAME OR NOT OPT_TYPE OR NOT OPT_DOC OR NOT OPT_STATES)
    message(FATAL_ERROR "acpp_option requires NAME, TYPE, STATES and DOC")
  endif()

  foreach(state IN LISTS OPT_STATES)
    if(NOT state MATCHES "^(building|driving|running)$")
      message(FATAL_ERROR
        "acpp_option(${OPT_NAME}): '${state}' is not a state. Use building, "
        "driving or running - the names the specification uses.")
    endif()
  endforeach()

  # The discovered value is the default, so a toolchain built without any
  # options set behaves exactly as it does today and works on the machine that
  # built it. Relocatability changes what is written, never how it is read.
  set(default "")
  if(OPT_DEFAULT_FROM AND DEFINED ${OPT_DEFAULT_FROM})
    set(default "${${OPT_DEFAULT_FROM}}")
  endif()

  set(${OPT_NAME} "${default}" CACHE ${OPT_TYPE} "${OPT_DOC}")

  set_property(GLOBAL PROPERTY ACPP_OPTION_${OPT_NAME}_STATES "${OPT_STATES}")
  set_property(GLOBAL PROPERTY ACPP_OPTION_${OPT_NAME}_RELATIVE "${OPT_RELATIVE}")
  set_property(GLOBAL PROPERTY ACPP_OPTION_${OPT_NAME}_DOC "${OPT_DOC}")
  set_property(GLOBAL PROPERTY ACPP_OPTION_${OPT_NAME}_BACKEND "${OPT_BACKEND}")

  # Appending to an empty string would leave a leading separator, and so an
  # empty element for every consumer that iterates the list.
  if(ACPP_DECLARED_OPTIONS)
    set(ACPP_DECLARED_OPTIONS "${ACPP_DECLARED_OPTIONS};${OPT_NAME}"
        CACHE INTERNAL "Every option declared by options.cmake")
  else()
    set(ACPP_DECLARED_OPTIONS "${OPT_NAME}"
        CACHE INTERNAL "Every option declared by options.cmake")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# Core - always declared
# ---------------------------------------------------------------------------

acpp_option(NAME ACPP_LLVM_BIN_DIR TYPE PATH
  STATES driving running
  DEFAULT_FROM LLVM_TOOLS_BINARY_DIR
  RELATIVE "${CMAKE_INSTALL_BINDIR}"
  DOC "Directory holding llc, lld and opt")

acpp_option(NAME ACPP_CLANG TYPE FILEPATH
  STATES driving running
  DEFAULT_FROM CLANG_C_EXECUTABLE_PATH
  RELATIVE "${CMAKE_INSTALL_BINDIR}/clang"
  DOC "The clang C driver")

acpp_option(NAME ACPP_CLANGXX TYPE FILEPATH
  STATES driving running
  DEFAULT_FROM CLANG_EXECUTABLE_PATH
  RELATIVE "${CMAKE_INSTALL_BINDIR}/clang++"
  DOC "The clang C++ driver. This is what compiles device code, and it must be
       the C++ driver: pointing it at 'clang' fails in ways that are hard to read")

acpp_option(NAME ACPP_CLANG_INCLUDE_DIR TYPE PATH
  STATES driving
  DEFAULT_FROM CLANG_INCLUDE_PATH
  RELATIVE "${CMAKE_INSTALL_LIBDIR}/clang/${LLVM_VERSION_MAJOR}/include"
  DOC "clang's own resource include directory")

acpp_option(NAME ACPP_HOST_CXX TYPE FILEPATH
  STATES driving
  DEFAULT_FROM CMAKE_CXX_COMPILER
  RELATIVE "${CMAKE_INSTALL_BINDIR}/clang++"
  DOC "Host C++ compiler used when targeting CPUs. Note that 'host' here means
       CPU rather than device, which is not the autotools sense of the word")

acpp_option(NAME ACPP_VECTOR_MATH_LIB TYPE STRING
  STATES running
  DEFAULT_FROM DEFAULT_VEC_MATH_LIB
  DOC "Which vector math library the host JIT uses: sleef, armpl, svml or none.
       libmvec is deliberately not selectable - the only correct copy is the one
       the loader resolves in the process doing the JIT")

acpp_option(NAME ACPP_VECTOR_MATH_LIB_DIR TYPE PATH
  STATES running
  DOC "Directory holding the selected vector math library")

acpp_option(NAME ACPP_LIBOMP_PATH TYPE FILEPATH
  STATES driving running
  RELATIVE "${CMAKE_INSTALL_LIBDIR}"
  DOC "The OpenMP runtime")

acpp_option(NAME ACPP_LIBNUMA_PATH TYPE FILEPATH
  STATES running
  DOC "libnuma, used by the CPU backend for topology")

# ---------------------------------------------------------------------------
# CUDA - shaped after FindCUDAToolkit, so a reader who knows that module can
# guess these. ACPP_CUDA_ROOT alone is enough on a normal installation; the
# rest exist for distributions that lay the toolkit out differently, which is
# the common case rather than the exception.
# ---------------------------------------------------------------------------

if(WITH_CUDA_BACKEND)
  acpp_option(NAME ACPP_CUDA_ROOT TYPE PATH BACKEND cuda
    STATES driving
    DEFAULT_FROM CUDA_TOOLKIT_ROOT_DIR
    DOC "CUDA toolkit root. Setting this alone resolves the rest on a layout
         that matches a vendor installer")

  acpp_option(NAME ACPP_CUDA_COMPILER TYPE FILEPATH BACKEND cuda
    STATES driving
    DEFAULT_FROM NVCXX_COMPILER
    DOC "nvc++, for the nvcxx compilation flow")

  acpp_option(NAME ACPP_CUDA_LIBRARY_DIR TYPE PATH BACKEND cuda
    STATES driving running
    DOC "Directory holding the CUDA runtime libraries. Defaults to lib64 inside
         the toolkit, which is where an installer puts them and is not where
         every distribution does")

  acpp_option(NAME ACPP_CUDA_TARGET_DIR TYPE PATH BACKEND cuda
    STATES driving running
    DOC "Per-target directory, e.g. targets/x86_64-linux, for layouts that use one")

  acpp_option(NAME ACPP_CUDA_INCLUDE_DIR TYPE PATH BACKEND cuda
    STATES driving
    DOC "CUDA headers")

  acpp_option(NAME ACPP_CUDA_DEVICELIB_DIR TYPE PATH BACKEND cuda
    STATES building
    DEFAULT_FROM CUDA_DEVICE_LIBS_PATH
    DOC "Directory holding libdevice.10.bc. Read only when building the
         toolchain: the bitcode is placed beside our own, so at run time it is
         found relative to us rather than through configuration")
endif()

# ---------------------------------------------------------------------------
# ROCm - same shape as CUDA. The individual ROCm libraries (hiprtc,
# hsa-runtime64, amd_comgr, hsakmt, rocprofiler-register) are not separate
# options: they live in the library directory, so one entry resolves them all.
# ---------------------------------------------------------------------------

if(WITH_ROCM_BACKEND)
  acpp_option(NAME ACPP_ROCM_ROOT TYPE PATH BACKEND rocm
    STATES driving
    DEFAULT_FROM ROCM_PATH
    DOC "ROCm root")

  acpp_option(NAME ACPP_ROCM_COMPILER TYPE FILEPATH BACKEND rocm
    STATES driving running
    DEFAULT_FROM HIPCC_PATH
    DOC "hipcc")

  acpp_option(NAME ACPP_ROCM_LIBRARY_DIR TYPE PATH BACKEND rocm
    STATES driving running
    DOC "Directory holding the ROCm runtime libraries")

  acpp_option(NAME ACPP_ROCM_TARGET_DIR TYPE PATH BACKEND rocm
    STATES driving running
    DOC "Per-target directory, for layouts that use one")

  acpp_option(NAME ACPP_ROCM_INCLUDE_DIR TYPE PATH BACKEND rocm
    STATES driving
    DOC "ROCm headers")

  acpp_option(NAME ACPP_ROCM_DEVICELIB_DIR TYPE PATH BACKEND rocm
    STATES building
    DEFAULT_FROM ROCM_DEVICE_LIBS_PATH
    DOC "Directory holding the ROCm device bitcode. Read only when building the
         toolchain, for the same reason as the CUDA one")
endif()

# ---------------------------------------------------------------------------
# Level Zero and OpenCL declare no options.
#
# Both reach their implementations through a loader library - libze_loader and
# the ICD loader - which we ship alongside AdaptiveCpp. They are found relative
# to our own libraries, so there is nothing to configure. This is the
# architecture the CUDA and ROCm backends are being moved towards.
#
# The SPIR-V translator and our own device bitcode are likewise ours, built and
# installed by us, and need no options.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Vulkan - out of scope while the backend is experimental. clspv is found
# rather than built, so enabling this backend will need an option; it is
# recorded here so the gap is deliberate rather than forgotten.
#
#   acpp_option(NAME ACPP_CLSPV TYPE FILEPATH BACKEND vulkan STATES running ...)
# ---------------------------------------------------------------------------
