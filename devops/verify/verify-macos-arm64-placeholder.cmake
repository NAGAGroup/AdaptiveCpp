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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

set(ACPP_DISCOVERED_VK_FOUND OFF)
set(ACPP_DISCOVERED_VK_PREFIX "")
set(ACPP_DISCOVERED_VK_LIBDIR "")
set(ACPP_DISCOVERED_CLSPV_FOUND OFF)
set(ACPP_DISCOVERED_CLSPV_PREFIX "")
set(ACPP_DISCOVERED_CLSPV_BINDIR "")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake)

# Ours in toolchain mode (rule 1): always the deploy-layout placeholder,
# regardless of ACPP_DEPLOYMENT_STRATEGY.
expect_eq(ACPP_TOOLCHAIN_LLD "{{ acpp-root }}/bin/ld64.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_RUNTIME_ROOT/bin/ld64.lld")

# OMP is core now, already included above.
expect_eq(ACPP_OMP_LINK_LINE "-fopenmp -L{{ libomp-path }} -lomp")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/vk.cmake)
include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/clspv.cmake)

# Not `default`: the vendor unit's install root is the acpp-root/subdir
# placeholder regardless of what was found.
expect_eq(ACPP_VK_INSTALL_ROOT "{{ acpp-root }}/{{ vk-subdir }}")
expect_eq(ACPP_VK_RT_SUBDIR "")
expect_eq(ACPP_CLSPV_INSTALL_ROOT "{{ acpp-root }}/{{ clspv-subdir }}")
# Not found -> the two cmake-level template strings for the executable are
# identical to the found case: neither branches on discovery or strategy at
# configure time.
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
expect_eq(ACPP_APP_CLSPV "\$ACPP_RUNTIME_ROOT/{{ clspv-subdir }}/{{ clspv-bin-subdir }}/clspv")

message(STATUS "macos/arm64 (placeholder): all checks passed")
