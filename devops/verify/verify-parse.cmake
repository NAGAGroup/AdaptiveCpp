# Parse check for cmake files that cannot be included in script mode - a
# CMakeLists.txt with project() and target commands. Run with cmake -P:
#   cmake -P devops/verify/verify-parse.cmake <file> [<file> ...]
# Paths are relative to the working directory. Exit 0 iff every file parses.
#
# The rule this encodes (measured on cmake 3.31): flow-control nesting and
# parse errors are detected whole-file, before any command executes. So a
# file whose run fails on a non-scriptable command, or inside a module the
# file includes, has nevertheless parsed cleanly - those failures are the
# pass condition here. Only "not properly nested" and "Parse error" mean the
# file itself is broken.

set(idx 3)
while(DEFINED CMAKE_ARGV${idx})
  set(file ${CMAKE_ARGV${idx}})
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
  math(EXPR idx "${idx} + 1")
endwhile()

message(STATUS "parse: all files clean")
