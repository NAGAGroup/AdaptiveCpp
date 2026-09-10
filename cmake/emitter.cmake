# The emitter: copies the enabled set of the configuration and deploy-manifest
# source files and fills their install stubs.
#
# The source files under config/ are checked in with "stub" values. The build
# is the only thing that knows what the stubs resolve to, so the build is what
# records them. Nothing here generates content: the key vocabulary lives in
# the JSON files, and adding a key means editing a JSON file, not a generator.
#
# Inputs, all of which must be resolved when this file is included:
#   * the option variables from cmake/options.cmake;
#   * the link-line, compiler-flag and default-target variables from the root
#     CMakeLists;
#   * the OpenMP, NUMA and LLVM library results that src/ finds - find_library
#     results are cache entries, so they are visible here even though the find
#     ran in a subdirectory scope.
#
# Outputs, under ${ACPP_BINARY_ROOT}/config/:
#   * acpp-<name>.json, the toolchain configuration, one per enabled backend;
#   * deploy/acpp-deployment-manifest-<component>.json, the deploy manifests.
#
# Under the `default` strategy the configuration values are fully expanded:
# $ACPP_PATH becomes the install prefix and $ACPP_TARGET its value, so no core
# placeholder survives. Under `bundled` and `full` the placeholders stay and
# the driver resolves them at read time. The manifests keep their placeholders
# under every strategy: their origins are resolved when the deploy step runs,
# against the toolchain that is doing the deploying.

include_guard(GLOBAL)

# Fill one configuration entry: replace the entry's "value": "stub" with the
# resolved value. Entry objects contain no nested braces, so [^}]* bounds the
# match safely. A key whose entry is absent from the file simply does not
# match; the survivor check at the end of each emit function catches the
# opposite case, a file entry with no fill.
function(acpp_fill_entry content_var key value)
  string(REGEX REPLACE
    "(\"${key}\":[ \t]*{[^}]*\"value\":[ \t]*)\"stub\""
    "\\1\"${value}\"" out "${${content_var}}")
  set(${content_var} "${out}" PARENT_SCOPE)
endfunction()

# Fill one named stub in a manifest (toolchain-libdir, the external-libs
# paths). Same match discipline as the configuration entries.
function(acpp_fill_manifest_stub content_var name value)
  string(REGEX REPLACE
    "(\"${name}\":[ \t]*)\"stub\""
    "\\1\"${value}\"" out "${${content_var}}")
  set(${content_var} "${out}" PARENT_SCOPE)
endfunction()

# Expand the core placeholders under the `default` strategy, refuse a
# surviving stub, and write the result.
#
# Under `default`, section 7 requires that no placeholder survive, so both of
# section 6's passes run here: entry references are expanded against the
# filled values first, and the core placeholders afterwards - which also
# resolves any core placeholder a referenced value carried in. The names of
# the referenceable entries are passed as extra arguments, because they differ
# per file: the core file's tool paths reference the name entries and the
# vector math directories reference ACPP_LIBDIR, the cuda link line references
# ACPP_CUDA_LIB_PATH, the ROCm link line ACPP_ROCM_PATH. Under `bundled` and
# `full` nothing is expanded: the driver's read-time resolver does both passes.
function(acpp_finish_config content_var src dst)
  set(content "${${content_var}}")
  if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
    foreach(ref IN LISTS ARGN)
      string(REGEX REPLACE "\\$${ref}" "${${ref}}" content "${content}")
    endforeach()
    string(REPLACE "$ACPP_PATH" "${CMAKE_INSTALL_PREFIX}" content "${content}")
    string(REPLACE "$ACPP_TARGET" "${ACPP_TARGET}" content "${content}")
  endif()
  if(content MATCHES "\"value\": \"stub\"")
    message(FATAL_ERROR "configuration stub left unfilled in ${src}")
  endif()
  file(WRITE "${dst}" "${content}")
endfunction()

function(acpp_emit_config_core src dst)
  file(READ "${src}" content)

  # Build facts.
  acpp_fill_entry(content "version-major" "${ACPP_VERSION_MAJOR}")
  acpp_fill_entry(content "version-minor" "${ACPP_VERSION_MINOR}")
  acpp_fill_entry(content "version-patch" "${ACPP_VERSION_PATCH}")
  acpp_fill_entry(content "version-suffix" "${ACPP_VERSION_SUFFIX}")
  acpp_fill_entry(content "plugin-linked-into-llvm" "${LLVM_ADAPTIVECPP_LINK_INTO_TOOLS}")
  acpp_fill_entry(content "plugin-llvm-version-major" "${PLUGIN_LLVM_VERSION_MAJOR}")
  acpp_fill_entry(content "plugin-with-cpu-acceleration" "${WITH_ACCELERATED_CPU}")
  acpp_fill_entry(content "plugin-with-sscp-compiler" "${WITH_SSCP_COMPILER}")

  # Driver settings.
  acpp_fill_entry(content "default-clang" "${ACPP_CLANG}")
  acpp_fill_entry(content "default-cpu-cxx" "${ACPP_CPU_CXX}")
  acpp_fill_entry(content "default-clang-include-path" "${ACPP_CLANG_INCLUDE_PATH}")
  acpp_fill_entry(content "default-targets" "${DEFAULT_TARGETS}")
  acpp_fill_entry(content "default-is-dryrun" "false")
  acpp_fill_entry(content "default-use-accelerated-cpu" "${WITH_ACCELERATED_CPU}")
  acpp_fill_entry(content "default-sequential-link-line" "${SEQUENTIAL_LINK_LINE}")
  acpp_fill_entry(content "default-sequential-cxx-flags" "${SEQUENTIAL_CXX_FLAGS}")
  acpp_fill_entry(content "default-omp-link-line" "${OMP_LINK_LINE}")
  acpp_fill_entry(content "default-omp-cxx-flags" "${OMP_CXX_FLAGS}")
  acpp_fill_entry(content "default-is-explicit-multipass" "false")
  acpp_fill_entry(content "default-save-temps" "false")

  # Deployment settings.
  acpp_fill_entry(content "ACPP_DEPLOYMENT_STRATEGY" "${ACPP_DEPLOYMENT_STRATEGY}")
  acpp_fill_entry(content "ACPP_LIBDIR" "${ACPP_LIBDIR}")

  # The JIT's tools and flags (section 12).
  acpp_fill_entry(content "ACPP_CLANG_PATH" "${ACPP_CLANG_PATH}")
  acpp_fill_entry(content "ACPP_LLC_PATH" "${ACPP_LLC_PATH}")
  acpp_fill_entry(content "ACPP_LLD_PATH" "${ACPP_LLD_PATH}")
  acpp_fill_entry(content "ACPP_OPT_PATH" "${ACPP_OPT_PATH}")
  acpp_fill_entry(content "ACPP_LLC_NAME" "${ACPP_LLC_NAME}")
  acpp_fill_entry(content "ACPP_LLD_NAME" "${ACPP_LLD_NAME}")
  acpp_fill_entry(content "ACPP_OPT_NAME" "${ACPP_OPT_NAME}")
  acpp_fill_entry(content "ACPP_LLVMSPIRV_NAME" "${ACPP_LLVMSPIRV_NAME}")
  acpp_fill_entry(content "ACPP_VECTOR_MATH_LIB" "${ACPP_VECTOR_MATH_LIB}")
  acpp_fill_entry(content "ACPP_SLEEF_DIR" "${ACPP_SLEEF_DIR}")
  acpp_fill_entry(content "ACPP_AMATH_DIR" "${ACPP_AMATH_DIR}")
  acpp_fill_entry(content "ACPP_SVML_DIR" "${ACPP_SVML_DIR}")
  acpp_fill_entry(content "ACPP_LLC_ADDITIONAL_FLAGS" "${ACPP_LLC_ADDITIONAL_FLAGS}")
  acpp_fill_entry(content "ACPP_OPT_ADDITIONAL_FLAGS" "${ACPP_OPT_ADDITIONAL_FLAGS}")
  acpp_fill_entry(content "ACPP_LLC_HOST_CPU_FLAG" "${ACPP_LLC_HOST_CPU_FLAG}")
  acpp_fill_entry(content "ACPP_OPT_HOST_CPU_FLAG" "${ACPP_OPT_HOST_CPU_FLAG}")

  acpp_finish_config(content "${src}" "${dst}"
    ACPP_LIBDIR ACPP_LLC_NAME ACPP_LLD_NAME ACPP_OPT_NAME ACPP_LLVMSPIRV_NAME)
endfunction()

function(acpp_emit_config_cuda src dst)
  file(READ "${src}" content)
  acpp_fill_entry(content "default-nvcxx" "${ACPP_NVCXX}")
  acpp_fill_entry(content "default-cuda-path" "${ACPP_CUDA_PATH}")
  acpp_fill_entry(content "default-cuda-lib-path" "${ACPP_CUDA_LIB_PATH}")
  acpp_fill_entry(content "default-cuda-link-line" "${CUDA_LINK_LINE}")
  acpp_fill_entry(content "default-cuda-cxx-flags" "${CUDA_CXX_FLAGS}")
  acpp_fill_entry(content "ACPP_CUDA_DEVICE_LIBS_PATH" "${ACPP_CUDA_DEVICE_LIBS_PATH}")
  acpp_finish_config(content "${src}" "${dst}" ACPP_CUDA_LIB_PATH)
endfunction()

function(acpp_emit_config_rocm src dst)
  file(READ "${src}" content)
  acpp_fill_entry(content "default-rocm-path" "${ACPP_ROCM_PATH}")
  acpp_fill_entry(content "default-rocm-lib-path" "${ACPP_ROCM_LIB_PATH}")
  acpp_fill_entry(content "default-rocm-link-line" "${ROCM_LINK_LINE}")
  acpp_fill_entry(content "default-rocm-cxx-flags" "${ROCM_CXX_FLAGS}")
  acpp_fill_entry(content "ACPP_ROCM_DEVICE_LIBS_PATH" "${ACPP_ROCM_DEVICE_LIBS_PATH}")
  acpp_fill_entry(content "ACPP_HIPCC_PATH" "${ACPP_HIPCC_PATH}")
  acpp_finish_config(content "${src}" "${dst}" ACPP_ROCM_PATH)
endfunction()

function(acpp_emit_config_ocl src dst)
  file(READ "${src}" content)
  acpp_fill_entry(content "ACPP_OCL_LIB_PATH" "${ACPP_OCL_LIB_PATH}")
  acpp_finish_config(content "${src}" "${dst}")
endfunction()

function(acpp_emit_config_ze src dst)
  file(READ "${src}" content)
  acpp_fill_entry(content "ACPP_ZE_LIB_PATH" "${ACPP_ZE_LIB_PATH}")
  acpp_finish_config(content "${src}" "${dst}")
endfunction()

function(acpp_emit_config_vulkan src dst)
  file(READ "${src}" content)
  acpp_fill_entry(content "ACPP_CLSPV_PATH" "${ACPP_CLSPV_PATH}")
  acpp_finish_config(content "${src}" "${dst}")
endfunction()

function(acpp_emit_manifest src dst)
  file(READ "${src}" content)

  # toolchain-libdir is a fact about what this build produced.
  acpp_fill_manifest_stub(content "toolchain-libdir" "${CMAKE_INSTALL_LIBDIR}")

  # external-libs: the DT_NEEDED libraries, recorded where the install found
  # them. find_library's *-NOTFOUND results are false constants in cmake, so a
  # miss fills the empty string and the row is dropped when the manifest is
  # read, the same filter the driver applies today.
  set(acpp_manifest_libnuma "")
  if(NUMA_LIBRARY)
    set(acpp_manifest_libnuma "${NUMA_LIBRARY}")
  endif()
  acpp_fill_manifest_stub(content "libnuma" "${acpp_manifest_libnuma}")

  # openmp: the one library actually linked, not the unconditional pair.
  set(acpp_manifest_openmp "")
  if(OpenMP_omp_LIBRARY)
    set(acpp_manifest_openmp "${OpenMP_omp_LIBRARY}")
  elseif(OpenMP_gomp_LIBRARY)
    set(acpp_manifest_openmp "${OpenMP_gomp_LIBRARY}")
  elseif(hipSYCL_OpenMP_libomp_LIBRARY)
    set(acpp_manifest_openmp "${hipSYCL_OpenMP_libomp_LIBRARY}")
  endif()
  acpp_fill_manifest_stub(content "openmp" "${acpp_manifest_openmp}")

  # libLLVM: the discovered library or, when AdaptiveCpp is built as part of
  # LLVM and no find ran, our own install tree's copy, named the way our
  # libraries are.
  set(acpp_manifest_libllvm "$ACPP_PATH/${CMAKE_INSTALL_LIBDIR}/SHARED_LIB:LLVM")
  if(LLVM_LIBRARY)
    set(acpp_manifest_libllvm "${LLVM_LIBRARY}")
  endif()
  acpp_fill_manifest_stub(content "libLLVM" "${acpp_manifest_libllvm}")

  # Rows whose source the build did not produce are inapplicable, not missing
  # (section 8): on Windows the llvm-to-* libraries are linked statically into
  # the backends and hsa-runtime64 is not linked, so those rows go. Shipping
  # them would make every deploy there warn about libraries that are correctly
  # absent. The loader shim rows survive: their names are acpp-loader-*, and
  # the pattern matches the fronted soname, not the shim.
  if(WIN32)
    string(REGEX REPLACE "\n$" "" content "${content}")
    string(REPLACE "\n" ";" acpp_manifest_lines "${content}")
    list(FILTER acpp_manifest_lines EXCLUDE REGEX "SHARED_LIB:llvm-to-")
    list(FILTER acpp_manifest_lines EXCLUDE REGEX "SHARED_LIB:hsa-runtime64")
    string(REPLACE ";" "\n" content "${acpp_manifest_lines}")
    set(content "${content}\n")
  endif()

  if(content MATCHES "\"stub\"")
    message(FATAL_ERROR "manifest stub left unfilled in ${src}")
  endif()

  file(WRITE "${dst}" "${content}")
endfunction()

# ---------------------------------------------------------------------------
# Invocation: copy the enabled set of both families and fill their stubs.
# ---------------------------------------------------------------------------

set(ACPP_CONFIG_OUTPUT_DIR "${ACPP_BINARY_ROOT}/config")
file(MAKE_DIRECTORY "${ACPP_CONFIG_OUTPUT_DIR}")
file(MAKE_DIRECTORY "${ACPP_CONFIG_OUTPUT_DIR}/deploy")

acpp_emit_config_core("${ACPP_SOURCE_ROOT}/config/acpp-core.json"
  "${ACPP_CONFIG_OUTPUT_DIR}/acpp-core.json")
if(WITH_CUDA_BACKEND)
  acpp_emit_config_cuda("${ACPP_SOURCE_ROOT}/config/acpp-cuda.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/acpp-cuda.json")
endif()
if(WITH_ROCM_BACKEND)
  acpp_emit_config_rocm("${ACPP_SOURCE_ROOT}/config/acpp-rocm.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/acpp-rocm.json")
endif()
if(WITH_OPENCL_BACKEND)
  acpp_emit_config_ocl("${ACPP_SOURCE_ROOT}/config/acpp-ocl.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/acpp-ocl.json")
endif()
if(WITH_LEVEL_ZERO_BACKEND)
  acpp_emit_config_ze("${ACPP_SOURCE_ROOT}/config/acpp-ze.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/acpp-ze.json")
endif()
if(WITH_VULKAN_BACKEND)
  acpp_emit_config_vulkan("${ACPP_SOURCE_ROOT}/config/acpp-vulkan.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/acpp-vulkan.json")
endif()

acpp_emit_manifest("${ACPP_SOURCE_ROOT}/config/deploy/acpp-deployment-manifest-core.json"
  "${ACPP_CONFIG_OUTPUT_DIR}/deploy/acpp-deployment-manifest-core.json")
if(WITH_CUDA_BACKEND)
  acpp_emit_manifest("${ACPP_SOURCE_ROOT}/config/deploy/acpp-deployment-manifest-cuda.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/deploy/acpp-deployment-manifest-cuda.json")
endif()
if(WITH_ROCM_BACKEND)
  acpp_emit_manifest("${ACPP_SOURCE_ROOT}/config/deploy/acpp-deployment-manifest-hip.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/deploy/acpp-deployment-manifest-hip.json")
endif()
if(WITH_OPENCL_BACKEND)
  acpp_emit_manifest("${ACPP_SOURCE_ROOT}/config/deploy/acpp-deployment-manifest-ocl.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/deploy/acpp-deployment-manifest-ocl.json")
endif()
if(WITH_LEVEL_ZERO_BACKEND)
  acpp_emit_manifest("${ACPP_SOURCE_ROOT}/config/deploy/acpp-deployment-manifest-ze.json"
    "${ACPP_CONFIG_OUTPUT_DIR}/deploy/acpp-deployment-manifest-ze.json")
endif()
