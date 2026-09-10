# Parse-and-defaults check for cmake/options.cmake, run with cmake -P:
#   cmake -P devops/verify/verify-options.cmake
# (use the cmake the project builds with, e.g. .pixi/envs/dev/bin/cmake)
#
# Nothing is set except the two inputs a real configure always provides, so
# every option must land on its declared default - the state a bare configure
# begins from. A change that breaks parsing or moves a default fails here
# instead of on a build machine.
#
# Script-mode notes: CMAKE_SYSTEM_NAME and CMAKE_SYSTEM_PROCESSOR are empty
# under cmake -P, so platform branches take their fall-through paths; that is
# itself part of what this checks. Script mode cannot take -D overrides, so
# variants are separate files (see verify-options-cpu-cxx.cmake).

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(CMAKE_INSTALL_LIBDIR lib)
set(LLVM_VERSION_MAJOR 21)

include(${ACPP_REPO_ROOT}/cmake/options.cmake)

function(expect_unset name)
  if(DEFINED ${name})
    message(FATAL_ERROR "${name} should be unset with no backends enabled, is '${${name}}'")
  endif()
endfunction()

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Strategy and gate.
expect_eq(ACPP_DEPLOYMENT_STRATEGY "default")
expect_eq(ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN "OFF")

# Core.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  expect_eq(ACPP_TARGET "x86_64-linux")
else()
  expect_unset(ACPP_TARGET)
endif()
expect_eq(ACPP_LIBDIR "lib")
expect_eq(ACPP_CLANG "$ACPP_PATH/bin/clang++")
expect_eq(ACPP_CPU_CXX "$ACPP_PATH/bin/clang++")
expect_eq(ACPP_CLANG_PATH "$ACPP_PATH/bin/clang++")
expect_eq(ACPP_CLANG_INCLUDE_PATH "$ACPP_PATH/lib/clang/21/include")
expect_eq(ACPP_LLC_NAME "llc")
expect_eq(ACPP_LLD_NAME "ld.lld")
expect_eq(ACPP_OPT_NAME "opt")
expect_eq(ACPP_LLC_PATH "$ACPP_PATH/bin/$ACPP_LLC_NAME")
expect_eq(ACPP_LLD_PATH "$ACPP_PATH/bin/$ACPP_LLD_NAME")
expect_eq(ACPP_OPT_PATH "$ACPP_PATH/bin/$ACPP_OPT_NAME")
expect_eq(ACPP_LLVMSPIRV_NAME "llvm-spirv")
expect_eq(ACPP_LLC_HOST_CPU_FLAG "-mcpu=native")
expect_eq(ACPP_OPT_HOST_CPU_FLAG "--mcpu=native")
expect_eq(ACPP_LLC_ADDITIONAL_FLAGS "")
expect_eq(ACPP_OPT_ADDITIONAL_FLAGS "")
expect_eq(ACPP_VECTOR_MATH_LIB "")
expect_eq(ACPP_SLEEF_DIR "$ACPP_PATH/$ACPP_LIBDIR")
expect_eq(ACPP_AMATH_DIR "$ACPP_PATH/$ACPP_LIBDIR")
expect_eq(ACPP_SVML_DIR "$ACPP_PATH/$ACPP_LIBDIR")

# Backend sections: entirely absent with no backends enabled.
expect_unset(ACPP_CUDA_PATH)
expect_unset(ACPP_CUDA_LIB_PATH)
expect_unset(ACPP_CUDA_DEVICE_LIBS_PATH)
expect_unset(ACPP_NVCXX)
expect_unset(ACPP_ROCM_PATH)
expect_unset(ACPP_ROCM_LIB_PATH)
expect_unset(ACPP_ROCM_DEVICE_LIBS_PATH)
expect_unset(ACPP_HIPCC_PATH)
expect_unset(ACPP_OCL_LIB_PATH)
expect_unset(ACPP_ZE_LIB_PATH)
expect_unset(ACPP_CLSPV_PATH)

message(STATUS "options.cmake: parses clean, every default as declared")
