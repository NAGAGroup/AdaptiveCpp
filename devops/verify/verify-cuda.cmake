# Defaults check for the CUDA options file, run with cmake -P:
#   cmake -P devops/verify/verify-cuda.cmake
#
# Stand-ins for the CUDA discovery exports and the core inputs the options
# file inherits. The toolkit is found. The placeholder variant (toolkit not
# found) is in verify-cuda-placeholder.cmake.
#
# CUDA_LIBDIR/INCDIR/BINDIR/LIBDEVICE_DIR are all relative to
# ACPP_DISCOVERED_CUDA_PREFIX, which is their common ancestor - discovery
# computes the prefix as that ancestor and each of the four as
# file(RELATIVE_PATH) against it, so a conda-shaped layout (where they may
# share nothing above "/") works exactly as a normal toolkit layout does.

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
set(ACPP_DISCOVERED_LIBOMP_DIR "/usr/lib/llvm-21/lib")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

# CUDA discovery stand-ins.
set(ACPP_DISCOVERED_CUDA_FOUND ON)
set(ACPP_DISCOVERED_CUDA_PREFIX "/usr/local/cuda-12.9")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "9")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/cuda.cmake)

# The install subdir knob and the root it derives.
expect_eq(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")
expect_eq(ACPP_CUDA_INSTALL_ROOT "/usr/local/cuda-12.9")

# Subdirs inside the vendor unit - discovery's own relative facts, found ->
# passed straight through.
expect_eq(ACPP_CUDA_RT_SUBDIR "lib64")
expect_eq(ACPP_CUDA_INCLUDE_SUBDIR "include")
expect_eq(ACPP_CUDA_BIN_SUBDIR "bin")
expect_eq(ACPP_CUDA_LIBDEVICE_SUBDIR "nvvm/libdevice")

# The application's own view of each (D7): under `default` the same
# discovered vendor install the driver found, composed via the driver's own
# {{ }} entries.
expect_eq(ACPP_APP_CUDA_RT_DIR "{{ cuda-install-root }}/{{ cuda-rt-subdir }}")
expect_eq(ACPP_APP_CUDA_INCLUDE_DIR "{{ cuda-install-root }}/{{ cuda-include-subdir }}")
expect_eq(ACPP_APP_CUDA_BIN_DIR "{{ cuda-install-root }}/{{ cuda-bin-subdir }}")
expect_eq(ACPP_APP_CUDA_LIBDEVICE_DIR "{{ cuda-install-root }}/{{ cuda-libdevice-subdir }}")

# Driver-only: link line and flags.
expect_eq(ACPP_CUDA_LINK_LINE "-Wl,-rpath={{ cuda-install-root }}/{{ cuda-rt-subdir }} -L{{ cuda-install-root }}/{{ cuda-rt-subdir }} -lcudart")
expect_eq(ACPP_CUDA_CXX_FLAGS "-U__FLOAT128__ -U__SIZEOF_FLOAT128__ -isystem {{ acpp-root }}/include/AdaptiveCpp/hipSYCL/std/hiplike")

message(STATUS "cuda.cmake: parses clean, every default as declared")
