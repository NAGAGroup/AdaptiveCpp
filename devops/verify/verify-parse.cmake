# Parse check for cmake files that cannot be included in script mode - a
# CMakeLists.txt with project() and target commands. Run with cmake -P:
#   cmake -P devops/verify/verify-parse.cmake [<file> [<file> ...]]
# Paths passed as arguments are relative to the working directory. With no
# arguments, checks the repo root's own CMakeLists.txt - the one file this
# harness exists for, and the one every sweep across devops/verify/*.cmake
# in this repo invokes with no arguments, one file per `cmake -P` call - so
# it is exercised by default rather than needing a caller that remembers
# to pass it. Exit 0 iff every file parses.
#
# The rule this encodes (measured on cmake 3.31): flow-control nesting and
# parse errors are detected whole-file, before any command executes. So a
# file whose run fails on a non-scriptable command, or inside a module the
# file includes, has nevertheless parsed cleanly - those failures are the
# pass condition here. Only "not properly nested" and "Parse error" mean the
# file itself is broken.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(idx 3)
set(_files "")
while(DEFINED CMAKE_ARGV${idx})
  list(APPEND _files "${CMAKE_ARGV${idx}}")
  math(EXPR idx "${idx} + 1")
endwhile()
if(_files STREQUAL "")
  set(_files "${ACPP_REPO_ROOT}/CMakeLists.txt")
endif()

foreach(file ${_files})
  if(NOT EXISTS "${file}")
    message(FATAL_ERROR "no such file: ${file}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -P "${file}"
    OUTPUT_QUIET
    ERROR_VARIABLE err
    RESULT_VARIABLE res)
  if(err MATCHES "not properly nested|Parse error|Error processing file")
    message(FATAL_ERROR "${file} does not parse:\n${err}")
  endif()
endforeach()

message(STATUS "parse: all files clean")

# ---------------------------------------------------------------------------
# The wiring cannot silently disappear: the root CMakeLists.txt must still
# include cmake/discovery.cmake, include an options/<platform>/<arch>/
# core.cmake, and call acpp_generate_installed_configs - a plain string
# search over the file's own text, independent of whichever files the
# parse check above actually ran.
# ---------------------------------------------------------------------------
file(READ "${ACPP_REPO_ROOT}/CMakeLists.txt" _root_text)

string(FIND "${_root_text}" "cmake/discovery.cmake" _idx_discovery)
if(_idx_discovery EQUAL -1)
  message(FATAL_ERROR "CMakeLists.txt no longer includes cmake/discovery.cmake")
endif()

string(FIND "${_root_text}" "ACPP_OPTIONS_DIR}/core.cmake" _idx_options)
if(_idx_options EQUAL -1)
  message(FATAL_ERROR "CMakeLists.txt no longer includes the platform/arch options core.cmake")
endif()

string(FIND "${_root_text}" "acpp_generate_installed_configs(" _idx_generate)
if(_idx_generate EQUAL -1)
  message(FATAL_ERROR "CMakeLists.txt no longer calls acpp_generate_installed_configs")
endif()

message(STATUS "parse: root CMakeLists.txt still wires discovery, options and the installed configs")

# ---------------------------------------------------------------------------
# Same rule, for the backends' rpaths to shipped vendors (Commit 3 step
# 3e): src/runtime/CMakeLists.txt must still call acpp_add_vendor_rpaths -
# a plain string search, independent of whether any particular backend
# happens to be enabled in this parse check's own (non-)configure.
# ---------------------------------------------------------------------------
file(READ "${ACPP_REPO_ROOT}/src/runtime/CMakeLists.txt" _runtime_text)

string(FIND "${_runtime_text}" "acpp_add_vendor_rpaths(" _idx_rpaths)
if(_idx_rpaths EQUAL -1)
  message(FATAL_ERROR "src/runtime/CMakeLists.txt no longer calls acpp_add_vendor_rpaths")
endif()

message(STATUS "parse: src/runtime/CMakeLists.txt still wires the backends' vendor rpaths")

# ---------------------------------------------------------------------------
# Same rule, for the application install rpath (Commit 6): the installed
# CMake package's add_sycl_to_target must still append ACPP_APP_INSTALL_RPATH
# to a target's INSTALL_RPATH when it is non-empty - a plain string search,
# independent of whether this parse check's own (non-)configure ever
# actually computes a non-empty value.
# ---------------------------------------------------------------------------
file(READ "${ACPP_REPO_ROOT}/cmake/adaptivecpp-config.cmake.in" _adaptivecpp_config_text)

string(FIND "${_adaptivecpp_config_text}" "APPEND PROPERTY INSTALL_RPATH \"\${ACPP_APP_INSTALL_RPATH}\"" _idx_apprpath)
if(_idx_apprpath EQUAL -1)
  message(FATAL_ERROR "cmake/adaptivecpp-config.cmake.in no longer appends ACPP_APP_INSTALL_RPATH to INSTALL_RPATH")
endif()

message(STATUS "parse: adaptivecpp-config.cmake.in still gives applications the full strategy's install rpath")
