# Discovery check for the plugin mode, run with cmake -P:
#   cmake -P devops/verify/verify-discovery-plugin.cmake
#
# Runs the real plugin path - find_package(LLVM CONFIG) against an
# installed LLVM named by LLVM_DIR (env or a -C prefile; script mode cannot
# take -D) - and asserts the exports. Skips (exit 0) when no LLVM_DIR is
# set: the find cannot be exercised honestly without an installed LLVM,
# and a build-tree LLVM_DIR is rejected by design.

if(NOT DEFINED LLVM_DIR AND NOT DEFINED ENV{LLVM_DIR})
  message(STATUS "SKIP: no installed LLVM (set LLVM_DIR to run this check)")
  return()
endif()
if(NOT DEFINED LLVM_DIR)
  set(LLVM_DIR "$ENV{LLVM_DIR}")
endif()

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(ACPP_LLVM_COMPONENT OFF)

include(${ACPP_REPO_ROOT}/cmake/discovery.cmake)

if(NOT ACPP_DISCOVERED_LLVM_PREFIX OR ACPP_DISCOVERED_LLVM_PREFIX STREQUAL "/")
  message(FATAL_ERROR
    "prefix derivation failed on a real find: '${ACPP_DISCOVERED_LLVM_PREFIX}'")
endif()
if(NOT ACPP_DISCOVERED_LLVM_LIBDIR)
  message(FATAL_ERROR
    "libdir derivation failed on a real find: '${ACPP_DISCOVERED_LLVM_LIBDIR}'")
endif()
if(NOT ACPP_DISCOVERED_CLANG OR ACPP_DISCOVERED_CLANG MATCHES "-NOTFOUND$")
  message(FATAL_ERROR "clang was not found against the installed LLVM")
endif()
if(NOT ACPP_DISCOVERED_CLANG_INCLUDE)
  message(FATAL_ERROR
    "clang's resource directory was not found against the installed LLVM")
endif()
if(NOT DEFINED ACPP_DISCOVERED_LIBOMP_DIR)
  message(FATAL_ERROR "ACPP_DISCOVERED_LIBOMP_DIR not set")
endif()

message(STATUS "discovery (plugin mode): real find against ${ACPP_DISCOVERED_LLVM_PREFIX} exports clean")
