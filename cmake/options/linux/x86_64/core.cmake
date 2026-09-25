# Core options - linux, x86_64.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../common/core.cmake)

# SVML is x86-only: Intel's Short Vector Math Library and its runtime
# companion intlc are not available on aarch64. Its own vendor unit, the
# same two-knob shape as sleef/amath in the common file. Category
# provisionally permissive; svml comes from Intel's compiler runtime, and
# its actual redistribution terms are still to be checked against Intel's
# license during implementation, before this ships under full for real.
acpp_declare_vendor(SVML svml permissive)
acpp_declare_vendor_root(SVML svml ACPP_DISCOVERED_SVML_DIR "${ACPP_DISCOVERED_SVML_DIR}")
acpp_declare_vendor_app_root(SVML svml)
