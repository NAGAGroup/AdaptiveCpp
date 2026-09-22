# Defaults check for the macos/arm64 options under a non-default strategy,
# run with cmake -P:
#   cmake -P devops/verify/verify-macos-arm64-placeholder.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Core stand-ins.
set(ACPP_DISCOVERED_LLVM_PREFIX "/opt/acpp")
set(ACPP_DISCOVERED_LLVM_BINDIR "/opt/acpp/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/opt/acpp/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/opt/acpp/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "/opt/acpp/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
set(ACPP_DEPLOYMENT_STRATEGY "managed")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake)

expect_eq(ACPP_TOOLCHAIN_LLD "{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/ld64.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_PATH/{{ llvm-deploy-path }}/bin/ld64.lld")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/omp.cmake)

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp -L{{ libomp-path }} -lomp")

message(STATUS "macos/arm64 (placeholder): all checks passed")
