# Core options - linux, x86_64.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../common/core.cmake)

# SVML is x86-only: Intel's Short Vector Math Library and its runtime
# companion intlc are not available on aarch64.
acpp_declare_resource(SVML_DIR ACPP_DISCOVERED_SVML_DIR "${ACPP_DISCOVERED_SVML_DIR}" "{{ acpp-libdir }}")
