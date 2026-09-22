# Vulkan options - linux, aarch64.
#
# Include after core.cmake, only when the Vulkan backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the Vulkan loader in the vendor's own library directory, nothing
# else. Vulkan has no multipass flow, so the driver passes nothing.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Deploy path
# ---------------------------------------------------------------------------

acpp_require_relative(ACPP_VK_DEPLOY_PATH)
if(NOT DEFINED ACPP_VK_DEPLOY_PATH)
  set(ACPP_VK_DEPLOY_PATH "{{ acpp-libdir }}/hipSYCL/ext/vk")
endif()

# ---------------------------------------------------------------------------
# Provenance - where the deploy step copies from
# ---------------------------------------------------------------------------

acpp_declare_provenance(ACPP_VK_PATH
  ACPP_DISCOVERED_VK_PREFIX "${ACPP_DISCOVERED_VK_PREFIX}"
  "{{ vk-deploy-path }}")

if(NOT "${ACPP_DISCOVERED_VK_PREFIX}" STREQUAL "")
  set(_acpp_vk_abs_libdir "${ACPP_DISCOVERED_VK_PREFIX}/${ACPP_DISCOVERED_VK_LIBDIR}")
else()
  set(_acpp_vk_abs_libdir "")
endif()

acpp_declare_provenance(ACPP_VK_LIB_PATH
  ACPP_DISCOVERED_VK_LIBDIR "${_acpp_vk_abs_libdir}"
  "{{ vk-deploy-path }}/{{ vk-libdir }}")

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time. Vulkan has no multipass flow; the driver passes nothing.
