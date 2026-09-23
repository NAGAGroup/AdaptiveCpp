# Defaults check for the macos/arm64 options, run with cmake -P:
#   cmake -P devops/verify/verify-macos-arm64.cmake

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

set(_macos_cmake_files
  ${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake)
foreach(_f ${_macos_cmake_files})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${_f}"
    OUTPUT_QUIET ERROR_VARIABLE _err RESULT_VARIABLE _res)
  if(_err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${_f} does not parse:\n${_err}")
  endif()
endforeach()
message(STATUS "macos/arm64: all cmake files parse clean")

# ---- Core defaults ----

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

# Stand-in for a real configure's GNUInstallDirs.
set(CMAKE_INSTALL_LIBDIR "lib")
set(CMAKE_INSTALL_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/core.cmake)

expect_eq(ACPP_DEFAULT_STRATEGY_APP_CFG_DIR "$HOME/Library/Application Support/AdaptiveCpp/app-cfgs")
# LLD is ours in toolchain mode (rule 1): always the deploy-layout
# placeholder, `default` strategy notwithstanding.
expect_eq(ACPP_TOOLCHAIN_LLD "{{ acpp-root }}/bin/ld64.lld")
expect_eq(ACPP_APP_LLD "\$ACPP_RUNTIME_ROOT/bin/ld64.lld")
expect_eq(ACPP_VECTOR_MATH_LIB "none")
expect_eq(ACPP_SEQUENTIAL_LINK_LINE "-L{{ libomp-path }} -lomp")
expect_eq(ACPP_CPU_CXX "{{ acpp-root }}/bin/clang++")
expect_unset(ACPP_PLUGIN_PATH)
expect_unset(ACPP_LIBNUMA_PATH)
expect_unset(ACPP_TOOLCHAIN_SLEEF_DIR)
expect_unset(ACPP_TOOLCHAIN_AMATH_DIR)
expect_unset(ACPP_TOOLCHAIN_SVML_DIR)
# libomp is ours in toolchain mode: no vendor-unit declaration at all here.
expect_unset(ACPP_LIBOMP_SUBDIR)
expect_unset(ACPP_LIBOMP_INSTALL_ROOT)
message(STATUS "macos/arm64/core.cmake: defaults as declared")

# ---- OMP (now core) ----

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp -L{{ libomp-path }} -lomp")
expect_eq(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
message(STATUS "macos/arm64 core.cmake: omp values as declared")

# ---- VK found ----

set(ACPP_DISCOVERED_VK_FOUND ON)
set(ACPP_DISCOVERED_VK_LOADER "/opt/vulkansdk/macOS/lib/libvulkan.1.4.0.dylib")
set(ACPP_DISCOVERED_VK_PREFIX "/opt/vulkansdk/macOS")
set(ACPP_DISCOVERED_VK_LIBDIR "lib")
set(ACPP_DISCOVERED_VK_INCLUDE_DIR "/opt/vulkansdk/macOS/include")
set(ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY "/opt/vulkansdk/macOS/lib/libSPIRV-Tools.a")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/vk.cmake)

expect_eq(ACPP_VK_SUBDIR "lib/hipSYCL/ext/vk")
expect_eq(ACPP_VK_INSTALL_ROOT "/opt/vulkansdk/macOS")
expect_eq(ACPP_VK_RT_SUBDIR "lib")
expect_eq(ACPP_APP_VK_RT_SUBDIR "{{ vk-install-root }}/{{ vk-rt-subdir }}")
message(STATUS "macos/arm64/vk.cmake: found defaults as declared")

# ---- CLSPV found ----

set(ACPP_DISCOVERED_CLSPV_FOUND ON)
set(ACPP_DISCOVERED_CLSPV_EXECUTABLE "/opt/vulkansdk/macOS/bin/clspv")
set(ACPP_DISCOVERED_CLSPV_PREFIX "/opt/vulkansdk/macOS")
set(ACPP_DISCOVERED_CLSPV_BINDIR "bin")

include(${ACPP_REPO_ROOT}/cmake/options/macos/arm64/clspv.cmake)

expect_eq(ACPP_CLSPV_SUBDIR "lib/hipSYCL/ext/clspv")
expect_eq(ACPP_CLSPV_INSTALL_ROOT "/opt/vulkansdk/macOS")
expect_eq(ACPP_CLSPV_BIN_SUBDIR "bin")
expect_eq(ACPP_APP_CLSPV_BIN_SUBDIR "{{ clspv-install-root }}/{{ clspv-bin-subdir }}")
expect_eq(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
expect_eq(ACPP_APP_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
message(STATUS "macos/arm64/clspv.cmake: found defaults as declared")

message(STATUS "macos/arm64: all checks passed")
