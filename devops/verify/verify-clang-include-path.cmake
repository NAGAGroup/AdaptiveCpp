# Guards the clang-include-path / clang resource-directory change: discovery
# honours upstream's -DCLANG_INCLUDE_PATH and derives ACPP_DISCOVERED_CLANG_INCLUDE
# from it (or from the found builtin-header directory's parent); the dead
# ACPP_CLANG_INCLUDE_PATH app-config row (nothing read it) is gone; the hip
# flow still passes the value with -isystem; and no core.cmake still builds
# the old literal include-directory path. Run with cmake -P:
#   cmake -P devops/verify/verify-clang-include-path.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# ---------------------------------------------------------------------------
# (a) discovery.cmake honours -DCLANG_INCLUDE_PATH and derives the resource
# directory from the builtin-header find via get_filename_component.
# ---------------------------------------------------------------------------
file(READ "${ACPP_REPO_ROOT}/cmake/discovery.cmake" _discovery_text)

string(FIND "${_discovery_text}" "DEFINED CLANG_INCLUDE_PATH" _idx_defined)
if(_idx_defined EQUAL -1)
  message(FATAL_ERROR
    "cmake/discovery.cmake: does not honour upstream's -DCLANG_INCLUDE_PATH "
    "('DEFINED CLANG_INCLUDE_PATH' not found).")
endif()

string(FIND "${_discovery_text}" "get_filename_component(ACPP_DISCOVERED_CLANG_INCLUDE" _idx_get_filename)
if(_idx_get_filename EQUAL -1)
  message(FATAL_ERROR
    "cmake/discovery.cmake: does not derive ACPP_DISCOVERED_CLANG_INCLUDE "
    "from the builtin-header directory's parent "
    "('get_filename_component(ACPP_DISCOVERED_CLANG_INCLUDE' not found).")
endif()
message(STATUS "verify-clang-include-path: discovery.cmake honours -DCLANG_INCLUDE_PATH and derives the resource directory")

# ---------------------------------------------------------------------------
# (b) No app-config fragment still reads ACPP_CLANG_INCLUDE_PATH - nothing
# ever read it back, so the row was dead weight.
# ---------------------------------------------------------------------------
file(GLOB_RECURSE _app_cfg_files "${ACPP_REPO_ROOT}/config/*/app/*.cfg")
foreach(_f IN LISTS _app_cfg_files)
  file(READ "${_f}" _app_cfg_text)
  string(FIND "${_app_cfg_text}" "ACPP_CLANG_INCLUDE_PATH" _idx_app_row)
  if(NOT _idx_app_row EQUAL -1)
    message(FATAL_ERROR
      "${_f}: still carries an ACPP_CLANG_INCLUDE_PATH row - nothing reads "
      "it back; it should have been removed.")
  endif()
endforeach()
message(STATUS "verify-clang-include-path: no app-config fragment carries ACPP_CLANG_INCLUDE_PATH")

# ---------------------------------------------------------------------------
# (c) The hip flow still passes clang-include-path with -isystem, on both
# platforms that have a hip.cmake options file.
# ---------------------------------------------------------------------------
foreach(_hip_file
    "${ACPP_REPO_ROOT}/cmake/options/linux/common/hip.cmake"
    "${ACPP_REPO_ROOT}/cmake/options/windows/common/hip.cmake")
  file(READ "${_hip_file}" _hip_text)
  string(FIND "${_hip_text}" "-isystem {{ clang-include-path }}" _idx_isystem)
  if(_idx_isystem EQUAL -1)
    message(FATAL_ERROR
      "${_hip_file}: no longer passes clang-include-path with -isystem.")
  endif()
endforeach()
message(STATUS "verify-clang-include-path: the hip flow still passes clang-include-path with -isystem")

# ---------------------------------------------------------------------------
# (d) No core.cmake still builds the old literal include-directory path -
# every platform now takes it from ACPP_DISCOVERED_CLANG_RESOURCE_REL.
# ---------------------------------------------------------------------------
file(GLOB _core_files "${ACPP_REPO_ROOT}/cmake/options/*/common/core.cmake")
foreach(_f IN LISTS _core_files)
  file(READ "${_f}" _core_text)
  string(FIND "${_core_text}" "clang/\${LLVM_VERSION_MAJOR}/include" _idx_literal)
  if(NOT _idx_literal EQUAL -1)
    message(FATAL_ERROR
      "${_f}: still builds the old literal clang/\${LLVM_VERSION_MAJOR}/include "
      "path directly, instead of taking ACPP_DISCOVERED_CLANG_RESOURCE_REL "
      "from discovery.")
  endif()
endforeach()
message(STATUS "verify-clang-include-path: no core.cmake builds the old literal include-directory path")

message(STATUS "verify-clang-include-path: OK")
