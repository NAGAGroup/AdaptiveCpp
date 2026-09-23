# Defaults check for the HIP options file, run with cmake -P:
#   cmake -P devops/verify/verify-hip.cmake
#
# Stand-ins for the HIP discovery exports and the core inputs the options
# file inherits. The distribution is found. The placeholder variant
# (distribution not found) is in verify-hip-placeholder.cmake.

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

# HIP discovery stand-ins: found.
set(ACPP_DISCOVERED_HIP_FOUND ON)
set(ACPP_DISCOVERED_HIP_PREFIX "/opt/rocm-10.0.0")
set(ACPP_DISCOVERED_HIP_LIBDIR "lib")
set(ACPP_DISCOVERED_HIP_INCDIR "include")
set(ACPP_DISCOVERED_HIP_BITCODE_DIR "lib/llvm/amdgcn/bitcode")
set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "10")
set(ACPP_DISCOVERED_HIP_VERSION_MINOR "0")
set(ACPP_DISCOVERED_HIP_HIPRTC ON)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/hip.cmake)

# The install subdir knob and the root it derives.
expect_eq(ACPP_HIP_SUBDIR "lib/hipSYCL/ext/hip")
expect_eq(ACPP_HIP_INSTALL_ROOT "/opt/rocm-10.0.0")

# Subdirs inside the vendor unit - discovery's own relative facts.
expect_eq(ACPP_HIP_RT_SUBDIR "lib")
expect_eq(ACPP_HIP_INCLUDE_SUBDIR "include")
expect_eq(ACPP_HIP_BITCODE_SUBDIR "lib/llvm/amdgcn/bitcode")
# libhsa-runtime64/libamdhip64 DT_NEED librocm_sysdeps_* through their own
# $ORIGIN/rocm_sysdeps/lib RUNPATH, relative to RT specifically.
expect_eq(ACPP_HIP_SYSDEPS_SUBDIR "lib/rocm_sysdeps/lib")

# The application's own view of each (D7).
expect_eq(ACPP_APP_HIP_RT_SUBDIR "{{ hip-install-root }}/{{ hip-rt-subdir }}")
expect_eq(ACPP_APP_HIP_INCLUDE_SUBDIR "{{ hip-install-root }}/{{ hip-include-subdir }}")
expect_eq(ACPP_APP_HIP_BITCODE_SUBDIR "{{ hip-install-root }}/{{ hip-bitcode-subdir }}")
expect_eq(ACPP_APP_HIP_SYSDEPS_SUBDIR "{{ hip-install-root }}/{{ hip-sysdeps-subdir }}")

# Driver-only.
expect_eq(ACPP_HIP_LINK_LINE "-Wl,-rpath={{ hip-install-root }}/{{ hip-rt-subdir }} -L{{ hip-install-root }}/{{ hip-rt-subdir }} -lamdhip64")
expect_eq(ACPP_HIP_CXX_FLAGS "-isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike -isystem {{ clang-include-path }} -U__FLOAT128__ -U__SIZEOF_FLOAT128__ -I{{ hip-install-root }}/{{ hip-include-subdir }} --rocm-device-lib-path={{ hip-install-root }}/{{ hip-bitcode-subdir }} --rocm-path={{ hip-install-root }} -fhip-new-launch-api -mllvm -amdgpu-early-inline-all=true -mllvm -amdgpu-function-calls=false -D__HIP_ROCclr__")

message(STATUS "hip.cmake: parses clean, every default as declared")
