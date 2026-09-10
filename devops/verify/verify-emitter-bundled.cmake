# Bundled-strategy probe for the emitter, run with cmake -P:
#   cmake -P devops/verify/verify-emitter-bundled.cmake
#
# Under bundled, placeholders must SURVIVE in the configuration files - the
# driver's read-time resolver does the two passes - and the discovery results
# are ignored in favour of the convention locations.
# Emitted files land in /tmp/acpp-verify-build-bundled.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(ACPP_SOURCE_ROOT ${ACPP_REPO_ROOT})
set(ACPP_BINARY_ROOT /tmp/acpp-verify-build-bundled)

set(CMAKE_INSTALL_LIBDIR lib)
set(CMAKE_INSTALL_PREFIX /tmp/acpp-verify-install)
set(LLVM_VERSION_MAJOR 21)

set(ACPP_VERSION_MAJOR 1)
set(ACPP_VERSION_MINOR 2)
set(ACPP_VERSION_PATCH 3)
set(ACPP_VERSION_SUFFIX "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS true)
set(PLUGIN_LLVM_VERSION_MAJOR 21)
set(WITH_ACCELERATED_CPU true)
set(WITH_SSCP_COMPILER true)
set(DEFAULT_TARGETS "generic")
set(SEQUENTIAL_LINK_LINE "-lfoo")
set(SEQUENTIAL_CXX_FLAGS "-O2")
set(OMP_LINK_LINE "-fopenmp")
set(OMP_CXX_FLAGS "-fopenmp -O2")

set(WITH_CUDA_BACKEND ON)
set(WITH_ROCM_BACKEND ON)

# Discovery results exist, but under bundled they must NOT win.
set(CUDA_cudart_LIBRARY /opt/cuda/lib64/libcudart.so)
set(CUDA_TOOLKIT_ROOT_DIR /opt/cuda)
set(CUDA_DEVICE_LIBS_PATH /opt/cuda/nvvm/libdevice)
set(ROCM_PATH /opt/rocm)
set(ROCM_DEVICE_LIBS_PATH /opt/rocm/amdgcn/bitcode)
set(AMDHIP64_LIBRARY /opt/rocm/lib/libamdhip64.so)
set(CLANG_INCLUDE_PATH /usr/lib/llvm-21/lib/clang/21/include)
set(DEFAULT_VEC_MATH_LIB libmvec)
set(LIBSLEEF /usr/lib/aarch64-linux-gnu/libsleefgnuabi.so)

set(ACPP_DEPLOYMENT_STRATEGY bundled)

include(${ACPP_REPO_ROOT}/cmake/options.cmake)
include(${ACPP_REPO_ROOT}/cmake/emitter.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# The options themselves, before looking at what was emitted.
expect_eq(ACPP_DEPLOYMENT_STRATEGY "bundled")
expect_eq(ACPP_CUDA_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
expect_eq(ACPP_CUDA_DEVICE_LIBS_PATH "$ACPP_PATH/lib/hipSYCL/ext/bitcode/ptx")
expect_eq(ACPP_ROCM_LIB_PATH "$ACPP_PATH/targets/$ACPP_TARGET/lib")
expect_eq(ACPP_ROCM_DEVICE_LIBS_PATH "$ACPP_PATH/lib/hipSYCL/ext/bitcode/amdgcn")
expect_eq(ACPP_SLEEF_DIR "$ACPP_PATH/$ACPP_LIBDIR")
expect_eq(ACPP_LLC_PATH "$ACPP_PATH/bin/$ACPP_LLC_NAME")

# The emitted files keep every placeholder.
file(READ /tmp/acpp-verify-build-bundled/config/acpp-core.json core)
if(NOT core MATCHES "[$]ACPP_PATH/bin/[$]ACPP_LLC_NAME")
  message(FATAL_ERROR "bundled core config lost the llc path placeholder")
endif()
file(READ /tmp/acpp-verify-build-bundled/config/acpp-cuda.json cuda)
if(NOT cuda MATCHES "[$]ACPP_PATH/targets/[$]ACPP_TARGET/lib")
  message(FATAL_ERROR "bundled cuda config lost the vendor lib placeholder")
endif()
if(cuda MATCHES "/opt/cuda")
  message(FATAL_ERROR "bundled cuda config carries a discovered path")
endif()

message(STATUS "emitter under bundled: placeholders survive, discovery ignored")
