# Defaults check for the CUDA options file when no toolkit is found, run
# with cmake -P:
#   cmake -P devops/verify/verify-cuda-placeholder.cmake
#
# Every CUDA discovery export is empty. Under `default` strategy the vendor
# unit macros pass discovery's answer straight through, however it came out
# - so the install root and every subdir fact land empty too, honestly:
# nothing was found, which is not a configure error.

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

# CUDA discovery: nothing found.
set(ACPP_DISCOVERED_CUDA_FOUND OFF)
set(ACPP_DISCOVERED_CUDA_PREFIX "")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "")
set(ACPP_DISCOVERED_CUDA_LIBDIR "")
set(ACPP_DISCOVERED_CUDA_INCDIR "")
set(ACPP_DISCOVERED_CUDA_BINDIR "")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "")
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)

# The install subdir knob is independent of discovery.
expect_eq(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")

# Nothing found -> the install root and every subdir fact pass straight
# through as empty.
expect_eq(ACPP_CUDA_INSTALL_ROOT "")
expect_eq(ACPP_CUDA_RT_SUBDIR "")
expect_eq(ACPP_CUDA_INCLUDE_SUBDIR "")
expect_eq(ACPP_CUDA_BIN_SUBDIR "")
expect_eq(ACPP_CUDA_LIBDEVICE_SUBDIR "")

# The app-config template composes the same way regardless of what was
# found - the driver resolves {{ cuda-install-root }} itself at drive time.
expect_eq(ACPP_APP_CUDA_RT_SUBDIR "{{ cuda-install-root }}/{{ cuda-rt-subdir }}")
expect_eq(ACPP_APP_CUDA_INCLUDE_SUBDIR "{{ cuda-install-root }}/{{ cuda-include-subdir }}")
expect_eq(ACPP_APP_CUDA_BIN_SUBDIR "{{ cuda-install-root }}/{{ cuda-bin-subdir }}")
expect_eq(ACPP_APP_CUDA_LIBDEVICE_SUBDIR "{{ cuda-install-root }}/{{ cuda-libdevice-subdir }}")

# Driver-only: link line and flags are independent of discovery.
expect_eq(ACPP_CUDA_LINK_LINE "-Wl,-rpath={{ cuda-install-root }}/{{ cuda-rt-subdir }} -L{{ cuda-install-root }}/{{ cuda-rt-subdir }} -lcudart")
expect_eq(ACPP_CUDA_CXX_FLAGS "-U__FLOAT128__ -U__SIZEOF_FLOAT128__ -isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike")

message(STATUS "cuda.cmake (placeholder): parses clean, every default as declared")
