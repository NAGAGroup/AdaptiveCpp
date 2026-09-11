# Discovery check for the linked mode, run with cmake -P:
#   cmake -P devops/verify/verify-discovery.cmake
#
# The linked half is pure derivation - no find_* - so it runs whole in
# script mode, and this harness chains the core options file in the same
# process to assert the discovered branch end to end.
#
# The linked half includes LLVM's GetClangResourceDir module, which the
# parent build provides on its module path. The harness reaches it through
# an LLVM source tree: LLVM_SRC_DIR when set, else the sibling layout
# scripts/build.nu documents. Without one it skips - the module is the only
# piece that needs it.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(NOT DEFINED LLVM_SRC_DIR AND DEFINED ENV{LLVM_SRC_DIR})
  set(LLVM_SRC_DIR "$ENV{LLVM_SRC_DIR}")
endif()
if(NOT LLVM_SRC_DIR)
  file(GLOB _acpp_sibling "${ACPP_REPO_ROOT}/../llvm-project-*")
  foreach(_d IN LISTS _acpp_sibling)
    if(EXISTS "${_d}/cmake/Modules/GetClangResourceDir.cmake")
      set(LLVM_SRC_DIR "${_d}")
    endif()
  endforeach()
endif()
if(NOT EXISTS "${LLVM_SRC_DIR}/cmake/Modules/GetClangResourceDir.cmake")
  message(STATUS "SKIP: no LLVM source tree for GetClangResourceDir (set LLVM_SRC_DIR)")
  return()
endif()
list(APPEND CMAKE_MODULE_PATH "${LLVM_SRC_DIR}/cmake/Modules")

# Stand-ins for the parent LLVM build.
set(ACPP_LLVM_COMPONENT ON)
set(LLVM_ADAPTIVECPP_LINK_IN_TOOLS ON)
set(CMAKE_INSTALL_PREFIX "/opt/acpp-toolchain")
set(LLVM_VERSION_MAJOR 21)
set(CLANG_VERSION_MAJOR 21)

include(${ACPP_REPO_ROOT}/cmake/discovery.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

expect_eq(ACPP_DISCOVERED_LLVM_PREFIX "/opt/acpp-toolchain")
expect_eq(ACPP_DISCOVERED_LLVM_BINDIR "/opt/acpp-toolchain/bin")
expect_eq(ACPP_DISCOVERED_LLVM_LIBDIR "lib")
expect_eq(ACPP_DISCOVERED_CLANG "/opt/acpp-toolchain/bin/clang++")
expect_eq(ACPP_DISCOVERED_CLANG_INCLUDE "/opt/acpp-toolchain/lib/clang/21/include")
expect_eq(ACPP_DISCOVERED_LIBOMP_DIR "/opt/acpp-toolchain/lib")

# Machine-level exports: real find_library runs in script mode. Every export
# must be DEFINED and carry no -NOTFOUND sentinel, whatever this box has.
foreach(_v IN ITEMS ACPP_DISCOVERED_LIBNUMA_DIR ACPP_DISCOVERED_SLEEF_DIR ACPP_DISCOVERED_AMATH_DIR ACPP_DISCOVERED_SVML_DIR)
  if(NOT DEFINED ${_v})
    message(FATAL_ERROR "${_v} not set - discovery did not run its machine-level half")
  endif()
  if("${${_v}}" MATCHES "-NOTFOUND")
    message(FATAL_ERROR "${_v} carries a -NOTFOUND sentinel: '${${_v}}'")
  endif()
endforeach()

# Chain: the options file must take the discovered branch against these
# values - same process, the include order the root will use.
include(${ACPP_REPO_ROOT}/cmake/options/linux/x86_64/core.cmake)

expect_eq(ACPP_LLVM_PATH "/opt/acpp-toolchain")
expect_eq(ACPP_LIBOMP_PATH "/opt/acpp-toolchain/lib")
expect_eq(ACPP_TOOLCHAIN_DEVICE_CMPLR "/opt/acpp-toolchain/bin/clang++")
expect_eq(ACPP_APP_DEVICE_CMPLR "/opt/acpp-toolchain/bin/clang++")
expect_eq(ACPP_TOOLCHAIN_LLC "/opt/acpp-toolchain/bin/llc")
expect_eq(ACPP_APP_LLC "/opt/acpp-toolchain/bin/llc")
expect_eq(ACPP_TOOLCHAIN_OPT "/opt/acpp-toolchain/bin/opt")
expect_eq(ACPP_TOOLCHAIN_LLD "/opt/acpp-toolchain/bin/ld.lld")
expect_eq(ACPP_TOOLCHAIN_LLVMSPIRV "/opt/acpp-toolchain/bin/llvm-spirv")
expect_eq(ACPP_TOOLCHAIN_CLANG_INCLUDE_PATH "/opt/acpp-toolchain/lib/clang/21/include")
expect_eq(ACPP_APP_CLANG_INCLUDE_PATH "/opt/acpp-toolchain/lib/clang/21/include")

message(STATUS "discovery (linked mode): derives clean, core takes the discovered branch")
