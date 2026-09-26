# Guards that install destinations follow GNUInstallDirs, run with cmake -P:
#   cmake -P devops/verify/verify-install-dirs.cmake
#
# The installed config and every vendor subdir/rpath already read
# CMAKE_INSTALL_LIBDIR/CMAKE_INSTALL_BINDIR; install() itself must too, or a
# lib64/multiarch layout disagrees with itself. FATAL_ERRORs on any line
# naming a literal "lib" or "bin" destination, or an INSTALL_RPATH walking
# "../lib" literally rather than through a computed rpath.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

file(GLOB_RECURSE _src_cmakelists "${ACPP_REPO_ROOT}/src/CMakeLists.txt")
set(_files "${ACPP_REPO_ROOT}/CMakeLists.txt" ${_src_cmakelists})

set(_bad_dest_pattern "DESTINATION[ \t]+\"?(lib|bin)([/ \t\")]|$)")
set(_bad_rpath_pattern "INSTALL_RPATH.*/\\.\\./lib")

set(_violations "")
foreach(_f IN LISTS _files)
  file(STRINGS "${_f}" _lines)
  set(_ln 0)
  foreach(_line IN LISTS _lines)
    math(EXPR _ln "${_ln} + 1")
    if("${_line}" MATCHES "${_bad_dest_pattern}")
      list(APPEND _violations "${_f}:${_ln}: ${_line}")
    endif()
    if("${_line}" MATCHES "${_bad_rpath_pattern}")
      list(APPEND _violations "${_f}:${_ln}: ${_line}")
    endif()
  endforeach()
endforeach()

if(_violations)
  string(JOIN "\n" _violations_joined ${_violations})
  message(FATAL_ERROR
    "verify-install-dirs: install destination(s) not following GNUInstallDirs:\n${_violations_joined}")
endif()

message(STATUS "verify-install-dirs: OK")
