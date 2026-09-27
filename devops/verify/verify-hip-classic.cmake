# Defaults check for the HIP options file against a classic ROCm layout
# (bitcode under amdgcn/bitcode, no rocm_sysdeps), run with cmake -P:
#   cmake -P devops/verify/verify-hip-classic.cmake
#
# Same stand-in shape as verify-hip.cmake (a TheRock-shaped layout), but
# for a classic /opt/rocm-* install: only the facts that differ between
# the two layouts are asserted here.

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
set(ACPP_DISCOVERED_CLANG_INCLUDE "/usr/lib/llvm-21/lib/clang/21")
set(ACPP_DISCOVERED_CLANG_RESOURCE_REL "lib/clang/21")
set(ACPP_DISCOVERED_LIBOMP_DIR "")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# HIP discovery stand-ins: classic ROCm layout found.
set(ACPP_DISCOVERED_HIP_FOUND ON)
set(ACPP_DISCOVERED_HIP_PREFIX "/opt/rocm-6.2.0")
set(ACPP_DISCOVERED_HIP_LIBDIR "lib")
set(ACPP_DISCOVERED_HIP_INCDIR "include")
set(ACPP_DISCOVERED_HIP_BITCODE_DIR "amdgcn/bitcode")
set(ACPP_DISCOVERED_HIP_SYSDEPS_DIR "")
set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "6")
set(ACPP_DISCOVERED_HIP_VERSION_MINOR "2")
set(ACPP_DISCOVERED_HIP_HIPRTC ON)

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/hip.cmake)

# The install subdir knob and the root it derives.
expect_eq(ACPP_HIP_INSTALL_ROOT "/opt/rocm-6.2.0")

# Bitcode lives directly under amdgcn/bitcode on a classic install, not
# under lib/llvm/amdgcn/bitcode (TheRock).
expect_eq(ACPP_HIP_BITCODE_SUBDIR "amdgcn/bitcode")

# A classic install has no rocm_sysdeps tree at all.
expect_eq(ACPP_HIP_SYSDEPS_SUBDIR "")

expect_eq(ACPP_APP_HIP_BITCODE_DIR "/opt/rocm-6.2.0/amdgcn/bitcode")

message(STATUS "hip.cmake (classic ROCm layout): parses clean, every default as declared")
