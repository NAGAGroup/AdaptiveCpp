# Variant of verify-options.cmake for the one option with a discovered
# branch that a bare cmake -P run cannot reach: ACPP_CPU_CXX records the
# C++ compiler the build used under the default strategy. The path need not
# exist - the option records the value verbatim; nothing executes it.
#   cmake -P devops/verify/verify-options-cpu-cxx.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(CMAKE_INSTALL_LIBDIR lib)
set(LLVM_VERSION_MAJOR 21)
set(CMAKE_CXX_COMPILER /usr/bin/g++)

include(${ACPP_REPO_ROOT}/cmake/options.cmake)

if(NOT "${ACPP_CPU_CXX}" STREQUAL "/usr/bin/g++")
  message(FATAL_ERROR "ACPP_CPU_CXX: expected the discovered '/usr/bin/g++', got '${ACPP_CPU_CXX}'")
endif()
if(NOT "${ACPP_CLANG}" STREQUAL "$ACPP_PATH/bin/clang++")
  message(FATAL_ERROR "ACPP_CLANG: expected '$ACPP_PATH/bin/clang++', got '${ACPP_CLANG}'")
endif()

message(STATUS "options.cmake: ACPP_CPU_CXX takes the discovered compiler, ACPP_CLANG stays the shipped clang")
