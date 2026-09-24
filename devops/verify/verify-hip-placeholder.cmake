# Defaults check for the HIP options file when no distribution is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-hip-placeholder.cmake
#
# Every HIP discovery export is empty; under `default` strategy the vendor
# unit macros pass discovery's answer straight through, so the install root
# and every subdir fact land empty too.

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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

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

expect_eq(ACPP_HIP_SUBDIR "lib/hipSYCL/ext/hip")

expect_eq(ACPP_HIP_INSTALL_ROOT "")
expect_eq(ACPP_HIP_RT_SUBDIR "")
expect_eq(ACPP_HIP_INCLUDE_SUBDIR "")
expect_eq(ACPP_HIP_BITCODE_SUBDIR "")
# Nothing found -> the sysdeps compose against an empty RT subdir, so it is
# empty too, not "/rocm_sysdeps/lib".
expect_eq(ACPP_HIP_SYSDEPS_SUBDIR "")

expect_eq(ACPP_APP_HIP_RT_DIR "{{ hip-install-root }}/{{ hip-rt-subdir }}")
expect_eq(ACPP_APP_HIP_INCLUDE_DIR "{{ hip-install-root }}/{{ hip-include-subdir }}")
expect_eq(ACPP_APP_HIP_BITCODE_DIR "{{ hip-install-root }}/{{ hip-bitcode-subdir }}")
expect_eq(ACPP_APP_HIP_SYSDEPS_DIR "{{ hip-install-root }}/{{ hip-sysdeps-subdir }}")

expect_eq(ACPP_HIP_LINK_LINE "-Wl,-rpath={{ hip-install-root }}/{{ hip-rt-subdir }} -L{{ hip-install-root }}/{{ hip-rt-subdir }} -lamdhip64")
expect_eq(ACPP_HIP_CXX_FLAGS "-isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-install-root }}/{{ hip-include-subdir }} --rocm-device-lib-path={{ hip-install-root }}/{{ hip-bitcode-subdir }} --rocm-path={{ hip-install-root }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")

message(STATUS "hip.cmake (placeholder): parses clean, every default as declared")
