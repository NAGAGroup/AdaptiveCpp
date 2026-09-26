# Negative-case child process for verify-install-sync.cmake: a synthetic
# "wanted" entry naming a file no install call provides must FATAL_ERROR.
# Entirely synthetic (no real config/cmake/install file involved) - this
# is a unit test of acpp_sync_require_covered itself, not a re-check of any
# real vendor's data.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${CMAKE_CURRENT_LIST_DIR}/verify-install-sync-lib.cmake)

set(_calls
  "FOO||LIB|bar"
  "FOO|ACPP_FOO_RT_SUBDIR|LIB|baz")

acpp_sync_require_covered("FOO||FILE|doesnotexist" "${_calls}" "scratch-manifest-row")

message(STATUS "should not be reached")
