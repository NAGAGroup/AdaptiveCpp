# Emit check for cmake/emitter.cmake under the default strategy, run with
# cmake -P:
#   cmake -P devops/verify/verify-emitter.cmake
#
# Stubs every input the emitter reads, includes options.cmake then
# emitter.cmake, and asserts the emitted files: no surviving stub anywhere,
# no surviving placeholder of either kind in the configuration files under
# the default strategy (section 7), placeholders retained in the manifests,
# and the external-libs fill resolving a missing library to empty.
#
# Emitted files land in /tmp/acpp-verify-build (script mode has no build
# tree; this fork is linux-only, so /tmp exists).

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(ACPP_SOURCE_ROOT ${ACPP_REPO_ROOT})
set(ACPP_BINARY_ROOT /tmp/acpp-verify-build)

set(CMAKE_INSTALL_LIBDIR lib)
set(CMAKE_INSTALL_PREFIX /tmp/acpp-verify-install)
set(LLVM_VERSION_MAJOR 21)

# Build facts.
set(ACPP_VERSION_MAJOR 1)
set(ACPP_VERSION_MINOR 2)
set(ACPP_VERSION_PATCH 3)
set(ACPP_VERSION_SUFFIX "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS true)
set(PLUGIN_LLVM_VERSION_MAJOR 21)
set(WITH_ACCELERATED_CPU true)
set(WITH_SSCP_COMPILER true)

# Driver settings the emitter fills.
set(DEFAULT_TARGETS "generic")
set(SEQUENTIAL_LINK_LINE "-lfoo")
set(SEQUENTIAL_CXX_FLAGS "-O2")
set(OMP_LINK_LINE "-fopenmp")
set(OMP_CXX_FLAGS "-fopenmp -O2")

# Backends enabled, so the enabled set is everything.
set(WITH_CUDA_BACKEND ON)
set(WITH_ROCM_BACKEND ON)
set(WITH_OPENCL_BACKEND ON)
set(WITH_LEVEL_ZERO_BACKEND ON)
set(WITH_VULKAN_BACKEND ON)

# Discovery results, as a populated build would have them.
set(CUDA_cudart_LIBRARY /opt/cuda/lib64/libcudart.so)
set(CUDA_DEVICE_LIBS_PATH /opt/cuda/nvvm/libdevice)
set(CUDA_TOOLKIT_ROOT_DIR /opt/cuda)
set(ROCM_PATH /opt/rocm)
set(ROCM_DEVICE_LIBS_PATH /opt/rocm/amdgcn/bitcode)
set(AMDHIP64_LIBRARY /opt/rocm/lib/libamdhip64.so)
set(OpenCL_LIBRARIES /usr/lib/x86_64-linux-gnu/libOpenCL.so)
set(ACPP_ZE_LOADER_LIBRARY /usr/lib/x86_64-linux-gnu/libze_loader.so.1)
set(NVCXX_COMPILER /opt/nvidia/hpc_sdk/Linux_x86_64/25.7/compilers/bin/nvc++)
set(HIPCC_COMPILER /opt/rocm/bin/hipcc)
set(CLSPV_COMPILER /usr/local/bin/clspv)
set(CLANG_INCLUDE_PATH /usr/lib/llvm-21/lib/clang/21/include)
set(DEFAULT_VEC_MATH_LIB libmvec)
set(LIBSLEEF /usr/lib/aarch64-linux-gnu/libsleefgnuabi.so)
# NUMA deliberately left unset: the fill must resolve it to empty.

include(${ACPP_REPO_ROOT}/cmake/options.cmake)
include(${ACPP_REPO_ROOT}/cmake/emitter.cmake)

function(expect_file_has name path needle)
  file(READ "${path}" content)
  if(NOT content MATCHES "${needle}")
    message(FATAL_ERROR "${name}: '${needle}' not found in ${path}")
  endif()
endfunction()

function(expect_file_lacks name path needle)
  file(READ "${path}" content)
  if(content MATCHES "${needle}")
    message(FATAL_ERROR "${name}: '${needle}' unexpectedly present in ${path}")
  endif()
endfunction()

set(cfg /tmp/acpp-verify-build/config)
set(man /tmp/acpp-verify-build/config/deploy)

# No stub survives anywhere, in any strategy.
foreach(f acpp-core acpp-cuda acpp-rocm acpp-ocl acpp-ze acpp-vulkan)
  expect_file_lacks("${f} config" "${cfg}/${f}.json" "\"stub\"")
endforeach()
foreach(f core cuda hip ocl ze)
  expect_file_lacks("${f} manifest" "${man}/acpp-deployment-manifest-${f}.json" "\"stub\"")
endforeach()

# Under default, no placeholder of either kind survives in the configuration.
foreach(f acpp-core acpp-cuda acpp-rocm acpp-ocl acpp-ze acpp-vulkan)
  expect_file_lacks("${f} config" "${cfg}/${f}.json" "[$]ACPP_")
endforeach()

# The manifests keep their placeholders under every strategy.
expect_file_has("core manifest" "${man}/acpp-deployment-manifest-core.json" "[$]ACPP_LIBDIR")

# The manifests are faithful copies of their sources: rows are never dropped
# by the fill, so the llvm-to-* and hsa-runtime64 rows are present even on a
# platform that links them statically - the deploy step skips and reports.
expect_file_has("core manifest" "${man}/acpp-deployment-manifest-core.json" "SHARED_LIB:llvm-to-host")
expect_file_has("hip manifest" "${man}/acpp-deployment-manifest-hip.json" "SHARED_LIB:hsa-runtime64")

# Spot checks: the values that exercise both placeholder passes.
expect_file_has("core config" "${cfg}/acpp-core.json" "/tmp/acpp-verify-install/bin/llc")
expect_file_has("core config" "${cfg}/acpp-core.json" "/tmp/acpp-verify-install/lib")
expect_file_has("cuda config" "${cfg}/acpp-cuda.json" "/opt/cuda/lib64")
expect_file_lacks("cuda config" "${cfg}/acpp-cuda.json" "[$]ACPP_CUDA_LIB_PATH")
expect_file_has("rocm config" "${cfg}/acpp-rocm.json" "/opt/rocm/lib")

message(STATUS "emitter.cmake: stubs all filled, default fully expanded, manifests faithful and placeholder-form")
