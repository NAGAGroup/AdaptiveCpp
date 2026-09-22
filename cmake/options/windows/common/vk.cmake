# Vulkan options - windows, every architecture.
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
  set(ACPP_VK_DEPLOY_PATH "{{ acpp-bindir }}/hipSYCL/ext/vk")
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

# The Vulkan SDK on Windows ships only the import library; the loader
# vulkan-1.dll lives in System32, installed by graphics drivers or the
# Vulkan runtime installer, and the loader's maintainers advise against
# bundling it. The Vulkan unit therefore deploys nothing on Windows, has no
# DLL directory resource, and the runtime reaches the machine's loader as
# it would a driver. The deploy path and provenance are kept for uniform
# shape.
