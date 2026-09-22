# Defaults check for the Vulkan options file, run with cmake -P:
#   cmake -P devops/verify/verify-vk.cmake

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

# Vulkan discovery: found.
set(ACPP_DISCOVERED_VK_FOUND ON)
set(ACPP_DISCOVERED_VK_LOADER "/usr/lib/x86_64-linux-gnu/libvulkan.so.1.3.290")
set(ACPP_DISCOVERED_VK_PREFIX "/usr")
set(ACPP_DISCOVERED_VK_LIBDIR "lib/x86_64-linux-gnu")
set(ACPP_DISCOVERED_VK_INCLUDE_DIR "/usr/include")
set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "/usr/lib/x86_64-linux-gnu/libSPIRV-Tools.a")

include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/vk.cmake)

expect_eq(ACPP_VK_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/vk")
expect_eq(ACPP_VK_PATH "/usr")
expect_eq(ACPP_VK_LIB_PATH "/usr/lib/x86_64-linux-gnu")

message(STATUS "vk.cmake: parses clean, every default as declared")
