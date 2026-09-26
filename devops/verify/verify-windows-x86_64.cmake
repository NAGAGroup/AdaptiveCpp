# Defaults check for the windows/x86_64 options, run with cmake -P:
#   cmake -P devops/verify/verify-windows-x86_64.cmake
#
# This harness runs on Linux; the Windows-only discovery branches are
# parse-checked but not exercised (WIN32 is not defined under -P on Linux).
#
# CUDA's LIBDEVICE_DIR is relative to ACPP_DISCOVERED_CUDA_PREFIX, like the
# other three CUDA facts - discovery's common-ancestor derivation, same as
# on Linux.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

function(expect_unset name)
  if(DEFINED ${name})
    message(FATAL_ERROR "${name} should be unset, is '${${name}}'")
  endif()
endfunction()

# ---- Parse check ----

set(_win_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/hip.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake
  ${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)
foreach(_f ${_win_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "windows/x86_64: all cmake files parse clean")

# ---- Core defaults ----

set(ACPP_DISCOVERED_LLVM_PREFIX "C:/acpp")
set(ACPP_DISCOVERED_LLVM_BINDIR "C:/acpp/bin")
set(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
set(ACPP_DISCOVERED_CLANG "C:/acpp/bin/clang++.exe")
set(ACPP_DISCOVERED_CLANG_INCLUDE "C:/acpp/lib/clang/21/include")
set(ACPP_DISCOVERED_LIBOMP_DIR "C:/acpp/bin")
set(ACPP_DISCOVERED_LIBNUMA_DIR "")
set(ACPP_DISCOVERED_SLEEF_DIR "")
set(ACPP_DISCOVERED_AMATH_DIR "")
set(ACPP_DISCOVERED_SVML_DIR "")
set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS ON)
# ACPP_LIBOMP_SOURCE_DIR would otherwise default off CMAKE_INSTALL_PREFIX,
# which this harness never sets; stand in directly with the same value
# ACPP_DISCOVERED_LIBOMP_DIR carries above. acpp_declare_vendor's WIN32
# branch would also pick the bindir-rooted subdir default; WIN32 is false
# on this Linux-hosted harness, so pre-set that too, the same override path
# a packager uses (see the CUDA/OCL/ZE/VK/CLSPV stand-ins below).
set(ACPP_LIBOMP_SOURCE_DIR "C:/acpp/bin")
set(ACPP_LIBOMP_SUBDIR "bin/hipSYCL/ext/libomp")

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/core.cmake)

# LLVM is ours in toolchain mode (rule 1): always the deploy-layout
# placeholder, the strategy notwithstanding. What we build follows cmake's
# own install directory under {{ acpp-root }} directly - no separate
# deploy-path knob, and no owned-provenance entries for either any more;
# libomp's actual shape as a vendor unit is below.
# libomp is a vendor unit in every build mode now (principle 3): not
# shipped under managed, but still ours in toolchain mode, so its install
# root is the deploy-layout placeholder rather than
# ACPP_LIBOMP_SOURCE_DIR's absolute value - see common/core.cmake's OMP
# section. Windows keeps the application-config declaration (unlike
# Linux/macOS): no RUNPATH, so AddDllDirectory still needs a directory,
# and not shipped means the discovered one.
expect_eq(ACPP_LIBOMP_SUBDIR "bin/hipSYCL/ext/libomp")
expect_eq(ACPP_LIBOMP_SHIPPED "OFF")
expect_eq(ACPP_LIBOMP_INSTALL_ROOT "{{ acpp-root }}/{{ acpp-libdir }}")
expect_eq(ACPP_LIBOMP_DISCOVERED_ROOT "C:/acpp/bin")
expect_eq(ACPP_APP_LIBOMP_INSTALL_ROOT "C:/acpp/bin")
# acpp_relative_from_rt_libdir's WIN32 branch anchors on CMAKE_INSTALL_
# BINDIR, the same directory lld-link.exe lands in, so on a real Windows
# configure this would need no "../". But WIN32 is false while this
# harness runs on Linux (cmake -P never defines it), so the function takes
# its non-WIN32 branch regardless of which platform's options file is
# included, anchoring on CMAKE_INSTALL_LIBDIR ("lib") instead - hence the
# "../bin/..." below, which is what this harness can actually exercise.
expect_eq(ACPP_TOOLCHAIN_LLD "{{ acpp-root }}/bin/lld-link.exe")
expect_eq(ACPP_APP_LLD "\$ACPP_RT_LIB_DIR/../bin/lld-link.exe")
expect_eq(ACPP_CPU_CXX "{{ acpp-root }}/{{ acpp-bindir }}/clang++.exe")
expect_unset(ACPP_PLUGIN_PATH)
expect_eq(ACPP_VECTOR_MATH_LIB "none")
expect_eq(ACPP_SEQUENTIAL_LINK_LINE "-llibomp")
expect_unset(ACPP_TOOLCHAIN_SLEEF_DIR)
expect_unset(ACPP_TOOLCHAIN_AMATH_DIR)
expect_unset(ACPP_TOOLCHAIN_SVML_DIR)
# No LIBNUMA_PATH declared on Windows.
expect_unset(ACPP_LIBNUMA_PATH)
message(STATUS "windows/x86_64/core.cmake: defaults as declared")

# ---- CUDA found ----

# acpp_declare_vendor_subdir's WIN32 branch picks the bindir-rooted default;
# WIN32 is a real platform macro that is false while this harness runs on
# Linux, so the subdir knobs are pre-set here exactly as a Windows configure
# would resolve them by default - the same override path a packager uses.
set(ACPP_CUDA_SUBDIR "bin/hipSYCL/ext/cuda")
set(ACPP_DISCOVERED_CUDA_PREFIX "C:/CUDA/v12.6")
set(ACPP_DISCOVERED_CUDA_LIBDIR "lib/x64")
set(ACPP_DISCOVERED_CUDA_INCDIR "include")
set(ACPP_DISCOVERED_CUDA_BINDIR "bin")
set(ACPP_DISCOVERED_CUDA_VERSION_MAJOR "12")
set(ACPP_DISCOVERED_CUDA_VERSION_MINOR "6")
set(ACPP_DISCOVERED_CUDA_LIBDEVICE_DIR "nvvm/libdevice")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/cuda.cmake)

expect_eq(ACPP_CUDA_SUBDIR "bin/hipSYCL/ext/cuda")
expect_eq(ACPP_CUDA_INSTALL_ROOT "C:/CUDA/v12.6")
expect_eq(ACPP_CUDA_RT_SUBDIR "lib/x64")
expect_eq(ACPP_CUDA_INCLUDE_SUBDIR "include")
expect_eq(ACPP_CUDA_BIN_SUBDIR "bin")
expect_eq(ACPP_CUDA_LIBDEVICE_SUBDIR "nvvm/libdevice")
# Not shipped under managed: a concrete cmake string, the discovered root
# joined with the subdir fact.
expect_eq(ACPP_APP_CUDA_RT_DIR "C:/CUDA/v12.6/lib/x64")
expect_eq(ACPP_APP_CUDA_INCLUDE_DIR "C:/CUDA/v12.6/include")
# BIN doubles as the DLL directory Windows feeds AddDllDirectory through.
expect_eq(ACPP_APP_CUDA_BIN_DIR "C:/CUDA/v12.6/bin")
expect_eq(ACPP_APP_CUDA_LIBDEVICE_DIR "C:/CUDA/v12.6/nvvm/libdevice")
expect_eq(ACPP_CUDA_LINK_LINE "-L{{ cuda-install-root }}/{{ cuda-rt-subdir }} -lcudart")
message(STATUS "windows/x86_64/cuda.cmake: found defaults as declared")

# ---- HIP found ----

# acpp_declare_vendor_subdir's WIN32 branch picks the bindir-rooted default;
# WIN32 is a real platform macro that is false while this harness runs on
# Linux, so the subdir knob is pre-set here exactly as a Windows configure
# would resolve it by default - the same override path a packager uses.
set(ACPP_HIP_SUBDIR "bin/hipSYCL/ext/hip")
set(ACPP_DISCOVERED_HIP_PREFIX "C:/Program Files/AMD/ROCm/6.2")
set(ACPP_DISCOVERED_HIP_LIBDIR "lib")
set(ACPP_DISCOVERED_HIP_INCDIR "include")
set(ACPP_DISCOVERED_HIP_BINDIR "bin")
set(ACPP_DISCOVERED_HIP_BITCODE_DIR "amdgcn/bitcode")
set(ACPP_DISCOVERED_HIP_SYSDEPS_DIR "")
set(ACPP_DISCOVERED_HIP_VERSION_MAJOR "6")
set(ACPP_DISCOVERED_HIP_VERSION_MINOR "2")
set(ACPP_DISCOVERED_HIP_HIPRTC ON)
set(ACPP_DISCOVERED_HIP_AMDHIP_DLL "amdhip64_6")
set(ACPP_DISCOVERED_HIP_COMGR_DLL "amd_comgr_2")
set(ACPP_DISCOVERED_HIP_HIPRTC_DLL "hiprtc0602")
set(ACPP_DISCOVERED_HIP_HIPRTC_BUILTINS_DLL "hiprtc-builtins0602")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/hip.cmake)

expect_eq(ACPP_HIP_SUBDIR "bin/hipSYCL/ext/hip")
expect_eq(ACPP_HIP_INSTALL_ROOT "C:/Program Files/AMD/ROCm/6.2")
expect_eq(ACPP_HIP_RT_SUBDIR "lib")
expect_eq(ACPP_HIP_INCLUDE_SUBDIR "include")
expect_eq(ACPP_HIP_BIN_SUBDIR "bin")
expect_eq(ACPP_HIP_BITCODE_SUBDIR "amdgcn/bitcode")
# Not shipped under managed: a concrete cmake string, the discovered root
# joined with the subdir fact.
expect_eq(ACPP_APP_HIP_RT_DIR "C:/Program Files/AMD/ROCm/6.2/lib")
expect_eq(ACPP_APP_HIP_INCLUDE_DIR "C:/Program Files/AMD/ROCm/6.2/include")
# BIN doubles as the DLL directory Windows feeds AddDllDirectory through.
expect_eq(ACPP_APP_HIP_BIN_DIR "C:/Program Files/AMD/ROCm/6.2/bin")
expect_eq(ACPP_APP_HIP_BITCODE_DIR "C:/Program Files/AMD/ROCm/6.2/amdgcn/bitcode")
expect_eq(ACPP_HIP_AMDHIP_DLL "amdhip64_6")
expect_eq(ACPP_HIP_LINK_LINE "-L{{ hip-install-root }}/{{ hip-rt-subdir }} -lamdhip64")
message(STATUS "windows/x86_64/hip.cmake: found defaults as declared")

# ---- OCL found ----

set(ACPP_OCL_SUBDIR "bin/hipSYCL/ext/ocl")
set(ACPP_DISCOVERED_OCL_FOUND ON)
set(ACPP_DISCOVERED_OCL_LOADER "C:/vendor/bin/OpenCL.dll")
set(ACPP_DISCOVERED_OCL_PREFIX "C:/vendor")
set(ACPP_DISCOVERED_OCL_LIBDIR "lib")
set(ACPP_DISCOVERED_OCL_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ocl.cmake)

expect_eq(ACPP_OCL_SUBDIR "bin/hipSYCL/ext/ocl")
expect_eq(ACPP_OCL_INSTALL_ROOT "C:/vendor")
expect_eq(ACPP_OCL_BIN_SUBDIR "bin")
expect_eq(ACPP_APP_OCL_BIN_DIR "C:/vendor/bin")
message(STATUS "windows/x86_64/ocl.cmake: found defaults as declared")

# ---- ZE found ----

set(ACPP_ZE_SUBDIR "bin/hipSYCL/ext/ze")
set(ACPP_DISCOVERED_ZE_FOUND ON)
set(ACPP_DISCOVERED_ZE_LOADER "C:/vendor/bin/ze_loader.dll")
set(ACPP_DISCOVERED_ZE_PREFIX "C:/vendor")
set(ACPP_DISCOVERED_ZE_LIBDIR "lib")
set(ACPP_DISCOVERED_ZE_BINDIR "bin")
set(ACPP_DISCOVERED_ZE_INCLUDE_DIR "C:/vendor/include")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/ze.cmake)

expect_eq(ACPP_ZE_SUBDIR "bin/hipSYCL/ext/ze")
expect_eq(ACPP_ZE_INSTALL_ROOT "C:/vendor")
expect_eq(ACPP_ZE_BIN_SUBDIR "bin")
expect_eq(ACPP_APP_ZE_BIN_DIR "C:/vendor/bin")
message(STATUS "windows/x86_64/ze.cmake: found defaults as declared")

# ---- OMP (now core) ----

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp")
expect_eq(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
message(STATUS "windows/x86_64 core.cmake: omp values as declared")

# ---- VK found ----

set(ACPP_VK_SUBDIR "bin/hipSYCL/ext/vk")
set(ACPP_DISCOVERED_VK_FOUND ON)
set(ACPP_DISCOVERED_VK_LOADER "C:/VulkanSDK/1.4.0/Lib/vulkan-1.lib")
set(ACPP_DISCOVERED_VK_PREFIX "C:/VulkanSDK/1.4.0")
set(ACPP_DISCOVERED_VK_LIBDIR "Lib")
set(ACPP_DISCOVERED_VK_INCLUDE_DIR "C:/VulkanSDK/1.4.0/Include")
set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "C:/VulkanSDK/1.4.0/Lib/SPIRV-Tools.lib")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/vk.cmake)

expect_eq(ACPP_VK_SUBDIR "bin/hipSYCL/ext/vk")
expect_eq(ACPP_VK_INSTALL_ROOT "C:/VulkanSDK/1.4.0")
expect_eq(ACPP_VK_RT_SUBDIR "Lib")
expect_eq(ACPP_APP_VK_RT_DIR "C:/VulkanSDK/1.4.0/Lib")
message(STATUS "windows/x86_64/vk.cmake: found defaults as declared")

# ---- CLSPV found ----

set(ACPP_CLSPV_SUBDIR "bin/hipSYCL/ext/clspv")
set(ACPP_DISCOVERED_CLSPV_FOUND ON)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "C:/VulkanSDK/1.4.0/Bin/clspv.exe")
set(ACPP_DISCOVERED_CLSPV_PREFIX "C:/VulkanSDK/1.4.0")
set(ACPP_DISCOVERED_CLSPV_BINDIR "Bin")

include(${ACPP_REPO_ROOT}/cmake/options/windows/x86_64/clspv.cmake)

expect_eq(ACPP_CLSPV_SUBDIR "bin/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_INSTALL_ROOT "C:/VulkanSDK/1.4.0")
expect_eq(ACPP_CLSPV_BIN_SUBDIR "Bin")
expect_eq(ACPP_APP_CLSPV_BIN_DIR "C:/VulkanSDK/1.4.0/Bin")
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv.exe")
expect_eq(ACPP_APP_CLSPV "C:/VulkanSDK/1.4.0/Bin/clspv.exe")
message(STATUS "windows/x86_64/clspv.cmake: found defaults as declared")

# The architecture files are one-line includes and the configuration is
# fragments across the common tiers, so a text mirror proves nothing;
# verify-common merges the fragments against the goldens.

message(STATUS "windows/x86_64: all checks passed")
