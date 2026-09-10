# AdaptiveCpp configuration options.
#
# The one place the cmake options a builder may override are gathered, so they
# are inspectable together. This is not a registry of configuration keys: the
# JSON files under config/ are that. Each option here feeds one configuration
# entry, and the install step fills that entry's stub with the option's value.
#
# Naming: an option carries the ACPP_ stem of the entry it feeds - the key for
# entries this overhaul adds, the environment variable for the legacy
# default-* entries, whose keys predate the ACPP_ convention. The one entry
# whose stem and environment variable differ is ACPP_VECTOR_MATH_LIB, whose
# environment variable is ACPP_JITOPT_HOST_VECTOR_MATH_LIBRARY, the name the
# runtime parses.
#
# No option here is a cache entry. An unguarded plain set() shadows a -D cache
# entry, so the builder's value would stop being read; every option is wrapped
# in if(NOT DEFINED ...), and DEFINED is true for a cache entry as well as a
# normal variable, so a -D wins everywhere. A second consequence of plain
# variables: values are recomputed on every configure, so flipping the
# deployment strategy cannot leave a stale absolute path behind.
#
# The value rule (doc/relocatable-overhaul-spec.md, section 5):
#   * a builder's -D wins verbatim and may itself contain placeholders;
#   * otherwise, under the `default` strategy, the discovered path when the
#     corresponding find_* found one;
#   * otherwise the declared default, in placeholder form.
# Discovery is one-directional: an option's value never feeds back into the
# find_* call. For resources the toolchain build itself installs - the LLVM
# tools, the clang drivers, the SPIR-V translator - the declared default is the
# install location and no discovery is involved.
#
# Include this file after: GNUInstallDirs, the LLVM version variables, backend
# detection (WITH_*_BACKEND), the CUDA toolkit and OpenCL discovery, the ROCm
# discovery including the ROCm runtime libraries, the Level Zero loader
# discovery, and the vector math library discovery. The value rule reads those
# results; the vendor-asset gate lists them.

# ---------------------------------------------------------------------------
# The deployment strategy (section 7)
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_DEPLOYMENT_STRATEGY)
  set(ACPP_DEPLOYMENT_STRATEGY "default")
endif()
if(NOT ACPP_DEPLOYMENT_STRATEGY MATCHES "^(default|bundled|full)$")
  message(FATAL_ERROR
    "ACPP_DEPLOYMENT_STRATEGY must be one of default, bundled or full, "
    "not '${ACPP_DEPLOYMENT_STRATEGY}'.")
endif()

# ---------------------------------------------------------------------------
# Vendor asset redistribution (section 9)
# ---------------------------------------------------------------------------
#
# Configuring `full` means the toolchain's own install tree will contain
# vendor assets, which is a redistribution decision: NVIDIA's CUDA runtime is
# governed by the CUDA Toolkit EULA and Intel's Level Zero loader and OpenCL
# ICD loader by their respective oneAPI redistribution terms. Read those terms
# before setting the gate below; this comment is the one place a toolchain
# builder is guaranteed to pass on the way in.
#
# The failure message lists the exact files that would be shipped, resolved
# from the discovery that has already run, so the choice is informed rather
# than a shrug at a boolean.

if(NOT DEFINED ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN)
  set(ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN OFF)
endif()

if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "full"
    AND NOT ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN)
  set(ACPP_FULL_VENDOR_ASSETS "")
  if(WITH_CUDA_BACKEND)
    if(CUDA_cudart_LIBRARY AND NOT CUDA_cudart_LIBRARY MATCHES "-NOTFOUND$")
      list(APPEND ACPP_FULL_VENDOR_ASSETS "${CUDA_cudart_LIBRARY}")
    endif()
    if(CUDA_DEVICE_LIBS_PATH AND NOT CUDA_DEVICE_LIBS_PATH MATCHES "-NOTFOUND$")
      list(APPEND ACPP_FULL_VENDOR_ASSETS "${CUDA_DEVICE_LIBS_PATH}/libdevice.10.bc")
    endif()
  endif()
  if(WITH_ROCM_BACKEND)
    foreach(asset IN ITEMS
        "${AMDHIP64_LIBRARY}"
        "${HSARUNTIME64_LIBRARY}"
        "${AMDCOMGR_LIBRARY}"
        "${HSAKMT_LIBRARY}"
        "${ROCPROFILERREGISTER_LIBRARY}"
        "${HIPRTC_LIBRARY}")
      if(asset AND NOT asset MATCHES "-NOTFOUND$")
        list(APPEND ACPP_FULL_VENDOR_ASSETS "${asset}")
      endif()
    endforeach()
    if(ROCM_DEVICE_LIBS_PATH AND NOT ROCM_DEVICE_LIBS_PATH MATCHES "-NOTFOUND$")
      list(APPEND ACPP_FULL_VENDOR_ASSETS "${ROCM_DEVICE_LIBS_PATH}/*")
    endif()
  endif()
  if(WITH_OPENCL_BACKEND)
    if(OpenCL_LIBRARIES AND NOT OpenCL_LIBRARIES MATCHES "-NOTFOUND$")
      list(APPEND ACPP_FULL_VENDOR_ASSETS "${OpenCL_LIBRARIES}")
    endif()
  endif()
  if(WITH_LEVEL_ZERO_BACKEND)
    if(ACPP_ZE_LOADER_LIBRARY AND NOT ACPP_ZE_LOADER_LIBRARY MATCHES "-NOTFOUND$")
      list(APPEND ACPP_FULL_VENDOR_ASSETS "${ACPP_ZE_LOADER_LIBRARY}")
    endif()
  endif()
  list(JOIN ACPP_FULL_VENDOR_ASSETS "\n" ACPP_FULL_VENDOR_ASSETS_LINES)
  message(FATAL_ERROR
    "ACPP_DEPLOYMENT_STRATEGY=full copies vendor assets into the toolchain's "
    "own install tree, which is a redistribution decision. The assets "
    "resolved on this machine are:\n${ACPP_FULL_VENDOR_ASSETS_LINES}\n"
    "Set ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN=ON to proceed "
    "having reviewed the vendors' redistribution terms (see the comment at "
    "this option's declaration in cmake/options.cmake).")
endif()

# ---------------------------------------------------------------------------
# The $ACPP_TARGET placeholder's value (section 6)
# ---------------------------------------------------------------------------
#
# Spelled the way CUDA's own installer and conda-forge spell the target
# subdirectory. Linux x86_64 is the only platform this tree ships; the
# spelling for any other platform is deliberately undecided here rather than
# guessed, and a builder must pass -DACPP_TARGET for one.

if(NOT DEFINED ACPP_TARGET)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    set(ACPP_TARGET "x86_64-linux")
  endif()
endif()

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

# The library directory a deployed application should use, relative to
# $ACPP_PATH (section 8). Its default is what this toolchain was installed
# with; a publisher may change it before shipping.
if(NOT DEFINED ACPP_LIBDIR)
  set(ACPP_LIBDIR "${CMAKE_INSTALL_LIBDIR}")
endif()

# The clang the driver invokes, and the host C++ compiler for CPU targets.
# Both are the clang this toolchain builds and installs; the C++ driver is
# what compiles SYCL. A builder may point the host compiler elsewhere (for
# example gcc for host code) without touching the device compiler.
if(NOT DEFINED ACPP_CLANG)
  set(ACPP_CLANG "$ACPP_PATH/bin/clang++")
endif()
if(NOT DEFINED ACPP_CPU_CXX)
  set(ACPP_CPU_CXX "$ACPP_PATH/bin/clang++")
endif()

# The clang the JIT invokes when compiling device code while an application
# runs (section 12). Also the shipped C++ driver.
if(NOT DEFINED ACPP_CLANG_PATH)
  set(ACPP_CLANG_PATH "$ACPP_PATH/bin/clang++")
endif()

# clang's own resource include directory. Standalone builds discover it;
# component builds install it, and the discovered value is then already the
# placeholder-form install location.
if(NOT DEFINED ACPP_CLANG_INCLUDE_PATH)
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
      AND CLANG_INCLUDE_PATH
      AND NOT CLANG_INCLUDE_PATH MATCHES "-NOTFOUND$")
    set(ACPP_CLANG_INCLUDE_PATH "${CLANG_INCLUDE_PATH}")
  else()
    set(ACPP_CLANG_INCLUDE_PATH
      "$ACPP_PATH/${CMAKE_INSTALL_LIBDIR}/clang/${LLVM_VERSION_MAJOR}/include")
  endif()
endif()

# The LLVM tools the JIT invokes while an application runs (section 12). The
# paths reference the name entries so the two cannot disagree; the names are
# unversioned because that is what this toolchain installs, and carry the
# platform executable suffix.
if(NOT DEFINED ACPP_LLC_NAME)
  if(WIN32)
    set(ACPP_LLC_NAME "llc.exe")
  else()
    set(ACPP_LLC_NAME "llc")
  endif()
endif()
if(NOT DEFINED ACPP_LLD_NAME)
  if(WIN32)
    set(ACPP_LLD_NAME "lld-link.exe")
  elseif(APPLE)
    set(ACPP_LLD_NAME "ld64.lld")
  else()
    set(ACPP_LLD_NAME "ld.lld")
  endif()
endif()
if(NOT DEFINED ACPP_OPT_NAME)
  if(WIN32)
    set(ACPP_OPT_NAME "opt.exe")
  else()
    set(ACPP_OPT_NAME "opt")
  endif()
endif()
if(NOT DEFINED ACPP_LLC_PATH)
  set(ACPP_LLC_PATH "$ACPP_PATH/bin/$ACPP_LLC_NAME")
endif()
if(NOT DEFINED ACPP_LLD_PATH)
  set(ACPP_LLD_PATH "$ACPP_PATH/bin/$ACPP_LLD_NAME")
endif()
if(NOT DEFINED ACPP_OPT_PATH)
  set(ACPP_OPT_PATH "$ACPP_PATH/bin/$ACPP_OPT_NAME")
endif()

# The SPIR-V translator binary. Its location is relative by construction
# (section 11); only the name varies, by platform.
if(NOT DEFINED ACPP_LLVMSPIRV_NAME)
  if(WIN32)
    set(ACPP_LLVMSPIRV_NAME "llvm-spirv.exe")
  else()
    set(ACPP_LLVMSPIRV_NAME "llvm-spirv")
  endif()
endif()

# Flags for the JIT's llc and opt invocations (section 12). The CPU flag's
# default is -mcpu=native, which llc and opt resolve on the machine doing the
# JIT; a builder or a deployed application may pin a concrete CPU instead.
# The additional-flags entries are empty by default and exist to be set.
if(NOT DEFINED ACPP_LLC_HOST_CPU_FLAG)
  set(ACPP_LLC_HOST_CPU_FLAG "-mcpu=native")
endif()
if(NOT DEFINED ACPP_OPT_HOST_CPU_FLAG)
  set(ACPP_OPT_HOST_CPU_FLAG "--mcpu=native")
endif()
if(NOT DEFINED ACPP_LLC_ADDITIONAL_FLAGS)
  set(ACPP_LLC_ADDITIONAL_FLAGS "")
endif()
if(NOT DEFINED ACPP_OPT_ADDITIONAL_FLAGS)
  set(ACPP_OPT_ADDITIONAL_FLAGS "")
endif()

# Which vector math library the host JIT uses. The build's discovery decides
# what the installed configuration says - sleef, armpl or svml when present,
# libmvec or none otherwise - and a deployed application can change it at run
# time; the enumerated values are the ones the runtime parses. libmvec needs
# no directory entry because the only correct copy is the one the loader
# resolves in the running process.
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "${DEFAULT_VEC_MATH_LIB}")
endif()

# One directory entry per vector math library (section 12). Each is
# directory-valued: the library's short name is written into the JIT's link
# invocation, so only the directory needs resolving. Under `bundled` and
# `full` the declared default is the toolchain's own library directory,
# which is also where the deploy manifests put them; under `default` the
# discovered directory wins.
foreach(acpp_vml IN ITEMS SLEEF AMATH SVML)
  if(NOT DEFINED ACPP_${acpp_vml}_DIR)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND LIB${acpp_vml}
        AND NOT LIB${acpp_vml} MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_${acpp_vml}_DIR "${LIB${acpp_vml}}" DIRECTORY)
    else()
      set(ACPP_${acpp_vml}_DIR "$ACPP_PATH/$ACPP_LIBDIR")
    endif()
  endif()
endforeach()

# ---------------------------------------------------------------------------
# CUDA
# ---------------------------------------------------------------------------

if(WITH_CUDA_BACKEND)

  # The CUDA toolkit root. The in-prefix convention is the target directory,
  # which lays out bin, include, lib and nvvm exactly as a toolkit root does.
  if(NOT DEFINED ACPP_CUDA_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND CUDA_TOOLKIT_ROOT_DIR
        AND NOT CUDA_TOOLKIT_ROOT_DIR MATCHES "-NOTFOUND$")
      set(ACPP_CUDA_PATH "${CUDA_TOOLKIT_ROOT_DIR}")
    else()
      set(ACPP_CUDA_PATH "$ACPP_PATH/targets/$ACPP_TARGET")
    endif()
  endif()

  # The directory holding the CUDA runtime libraries. An installer puts them
  # in lib64 inside the toolkit; conda-forge puts them in the target
  # directory's lib. This tree finds CUDA with the legacy FindCUDA module,
  # so the discovered directory is the one containing the found libcudart.
  if(NOT DEFINED ACPP_CUDA_LIB_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND CUDA_cudart_LIBRARY
        AND NOT CUDA_cudart_LIBRARY MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_CUDA_LIB_PATH "${CUDA_cudart_LIBRARY}" DIRECTORY)
    else()
      set(ACPP_CUDA_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
    endif()
  endif()

  # Where libdevice.10.bc lives. The declared default is where the deploy
  # step's `full` strategy copies it; a packager whose environment supplies
  # the bitcode overrides the entry (for conda, $ACPP_PATH/nvvm/libdevice).
  if(NOT DEFINED ACPP_CUDA_DEVICE_LIBS_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND CUDA_DEVICE_LIBS_PATH
        AND NOT CUDA_DEVICE_LIBS_PATH MATCHES "-NOTFOUND$")
      set(ACPP_CUDA_DEVICE_LIBS_PATH "${CUDA_DEVICE_LIBS_PATH}")
    else()
      set(ACPP_CUDA_DEVICE_LIBS_PATH "$ACPP_PATH/lib/hipSYCL/ext/bitcode/ptx")
    endif()
  endif()

  # nvc++ for the nvcxx compilation flow. Never shipped by this toolchain,
  # so the declared default is absent and the environment or the packager
  # supplies it.
  if(NOT DEFINED ACPP_NVCXX)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND NVCXX_COMPILER
        AND NOT NVCXX_COMPILER MATCHES "-NOTFOUND$")
      set(ACPP_NVCXX "${NVCXX_COMPILER}")
    else()
      set(ACPP_NVCXX "")
    endif()
  endif()

endif()

# ---------------------------------------------------------------------------
# ROCm
# ---------------------------------------------------------------------------

if(WITH_ROCM_BACKEND)

  # The ROCm root. The in-prefix convention is the prefix itself, which is
  # how conda-forge's ROCm packages lay it out.
  if(NOT DEFINED ACPP_ROCM_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default" AND ROCM_PATH)
      set(ACPP_ROCM_PATH "${ROCM_PATH}")
    else()
      set(ACPP_ROCM_PATH "$ACPP_PATH")
    endif()
  endif()

  # The directory holding the ROCm runtime libraries. Under `default` the
  # discovered directory of the first found runtime library wins; the
  # convention location is the vendor zone.
  if(NOT DEFINED ACPP_ROCM_LIB_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND AMDHIP64_LIBRARY
        AND NOT AMDHIP64_LIBRARY MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_ROCM_LIB_PATH "${AMDHIP64_LIBRARY}" DIRECTORY)
    else()
      set(ACPP_ROCM_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
    endif()
  endif()

  # Where the ROCm device bitcode lives. Same shape as the CUDA entry: the
  # declared default is where `full` copies it, and conda-forge's
  # rocm-device-libs overrides it with $ACPP_PATH/amdgcn/bitcode.
  if(NOT DEFINED ACPP_ROCM_DEVICE_LIBS_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND ROCM_DEVICE_LIBS_PATH
        AND NOT ROCM_DEVICE_LIBS_PATH MATCHES "-NOTFOUND$")
      set(ACPP_ROCM_DEVICE_LIBS_PATH "${ROCM_DEVICE_LIBS_PATH}")
    else()
      set(ACPP_ROCM_DEVICE_LIBS_PATH "$ACPP_PATH/lib/hipSYCL/ext/bitcode/amdgcn")
    endif()
  endif()

  # hipcc, for the ROCm interoperability flow. Never shipped by this
  # toolchain, so the declared default is absent.
  if(NOT DEFINED ACPP_HIPCC_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND HIPCC_COMPILER
        AND NOT HIPCC_COMPILER MATCHES "-NOTFOUND$")
      set(ACPP_HIPCC_PATH "${HIPCC_COMPILER}")
    else()
      set(ACPP_HIPCC_PATH "")
    endif()
  endif()

endif()

# ---------------------------------------------------------------------------
# OpenCL
# ---------------------------------------------------------------------------

if(WITH_OPENCL_BACKEND)

  # The directory holding the OpenCL ICD loader. The loader discovers vendor
  # drivers itself; this locates the loader. The entry is directory-valued
  # and the manifest deploys the loader into the vendor zone.
  if(NOT DEFINED ACPP_OCL_LIB_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND OpenCL_LIBRARIES
        AND NOT OpenCL_LIBRARIES MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_OCL_LIB_PATH "${OpenCL_LIBRARIES}" DIRECTORY)
    else()
      set(ACPP_OCL_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
    endif()
  endif()

endif()

# ---------------------------------------------------------------------------
# Level Zero
# ---------------------------------------------------------------------------

if(WITH_LEVEL_ZERO_BACKEND)

  # The directory holding libze_loader, the Level Zero loader. Same shape as
  # the OpenCL entry: the loader discovers drivers, this locates the loader.
  if(NOT DEFINED ACPP_ZE_LIB_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND ACPP_ZE_LOADER_LIBRARY
        AND NOT ACPP_ZE_LOADER_LIBRARY MATCHES "-NOTFOUND$")
      get_filename_component(ACPP_ZE_LIB_PATH "${ACPP_ZE_LOADER_LIBRARY}" DIRECTORY)
    else()
      set(ACPP_ZE_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
    endif()
  endif()

endif()

# ---------------------------------------------------------------------------
# Vulkan - the backend is experimental and OFF by default; the option exists
# so the gap is recorded rather than forgotten (section 8).
# ---------------------------------------------------------------------------

if(WITH_VULKAN_BACKEND)

  if(NOT DEFINED ACPP_CLSPV_PATH)
    if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default"
        AND CLSPV_COMPILER
        AND NOT CLSPV_COMPILER MATCHES "-NOTFOUND$")
      set(ACPP_CLSPV_PATH "${CLSPV_COMPILER}")
    else()
      set(ACPP_CLSPV_PATH "")
    endif()
  endif()

endif()
