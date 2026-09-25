# Inner process for verify-vendor-install.cmake's missing-library case.
# Never run directly - a FATAL_ERROR here would abort the harness itself if
# run in-process, so it is spawned via `cmake -P`, and the harness checks
# the child's own exit code and stderr instead.
#
# Required -D: ACPP_TEST_DIR (a directory that exists but holds no library
# named "doesnotexist").

get_filename_component(_acpp_repo_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${_acpp_repo_root}/cmake/acpp-vendor-install.cmake)

if(NOT DEFINED ACPP_TEST_DIR)
  message(FATAL_ERROR "ACPP_TEST_DIR must be passed via -D")
endif()

set(ACPP_FOO_SHIPPED ON)
set(ACPP_FOO_DISCOVERED_ROOT "${ACPP_TEST_DIR}")
set(ACPP_FOO_SUBDIR "ext/foo")

# ACPP_FOO_DISCOVERED_ROOT exists (the fake tree the harness built), so
# this takes the immediate, configure-time-checked branch - the one that
# is supposed to FATAL_ERROR here, naming "doesnotexist".
acpp_install_vendor_libs(STEM FOO FACT "" NAMES doesnotexist)

message(STATUS "verify-vendor-install (inner): should not reach here")
