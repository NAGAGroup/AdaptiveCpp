# Vulkan vendor install rule - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. A
# no-op unless ACPP_VK_SHIPPED. A loader-only unit on Linux: the Vulkan
# loader is the whole thing (config/linux/common/deploy/vk.json's sole
# external-permissive row). The Vulkan headers and the static SPIRV-Tools
# archive are build-only discovery requirements (cmake/discovery/vk.cmake's
# own header) - never a vendor asset, so no toolchain-only piece here.

acpp_install_vendor_libs(STEM VK FACT "${ACPP_VK_RT_SUBDIR}" NAMES vulkan)
