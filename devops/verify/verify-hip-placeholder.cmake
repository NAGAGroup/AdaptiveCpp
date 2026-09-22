# Defaults check for the HIP options file when no distribution is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-hip-placeholder.cmake
#
# Every HIP discovery export is empty; the options must fall to the
# placeholder shape on every declaration.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# Core stand-ins.
set(ACPP_DISCOVERED_LLVM_PREFIX "/usr/lib/llvm-21")
set(ACPP_DISCOVERED_LLVM_BINDIR "/usr/lib/llvm-21/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "/usr/lib/llvm-21/bin/clang++")
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# HIP discovery: nothing found.
set(ACPP_DISCOVERED_HIP_FOUND OFF)
set(ACPP_DISCOVERED_HIP_PREFIX "")
set(ACPP_DISCOVERED_HIP_LIBDIR "")
set(ACPP_DISCOVERED_HIP_INCDIR "")
set(ACPP_DISCOVERED_HIP_BITCODE_DIR "")
set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "")
set(ACPP_DISCOVERED_HIP_VERSION_MINOR "")
set(ACPP_DISCOVERED_HIP_HIPRTC OFF)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/hip.cmake)

# Deploy path is independent of discovery.
expect_eq(ACPP_HIP_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/hip")

# Provenance: not found -> placeholder shape.
expect_eq(ACPP_HIP_PATH "{{ toolchain-path }}/{{ hip-deploy-path }}")
expect_eq(ACPP_HIP_LIB_PATH "{{ toolchain-path }}/{{ hip-deploy-path }}/{{ hip-libdir }}")
expect_eq(ACPP_HIP_INCLUDE_PATH "{{ toolchain-path }}/{{ hip-deploy-path }}/{{ hip-incdir }}")
expect_eq(ACPP_HIP_SYSDEPS_PATH "{{ toolchain-path }}/{{ hip-deploy-path }}/{{ hip-libdir }}/rocm_sysdeps/lib")

# Resource: two-sided, not found -> placeholder shape.
expect_eq(ACPP_TOOLCHAIN_HIP_DEVICE_LIBS_DIR "{{ toolchain-path }}/{{ hip-deploy-path }}/{{ hip-bitcode-dir }}")
expect_eq(ACPP_APP_HIP_DEVICE_LIBS_DIR "\$ACPP_PATH/{{ hip-deploy-path }}/{{ hip-bitcode-dir }}")

# Driver-only.
expect_eq(ACPP_HIP_LINK_LINE "-Wl,-rpath={{ hip-lib-path }} -L{{ hip-lib-path }} -lamdhip64")
expect_eq(ACPP_HIP_CXX_FLAGS "-isystem {{ toolchain-path }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-include-path }} --rocm-device-lib-path={{ hip-device-libs-dir }} --rocm-path={{ hip-path }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")

message(STATUS "hip.cmake (placeholder): parses clean, every default as declared")
