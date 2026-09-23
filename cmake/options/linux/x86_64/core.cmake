# Core options - linux, x86_64.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../common/core.cmake)

# SVML is x86-only: Intel's Short Vector Math Library and its runtime
# companion intlc are not available on aarch64. Its own vendor unit
# (rule 3/4), the same two-knob shape as sleef/amath in the common file.
acpp_declare_vendor_subdir(SVML svml)
acpp_declare_vendor_root(SVML svml ACPP_DISCOVERED_SVML_DIR "${ACPP_DISCOVERED_SVML_DIR}")
acpp_declare_vendor_app_root(SVML svml)
