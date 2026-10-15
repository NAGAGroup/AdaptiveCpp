# Vulkan vendor install rule - macOS, every architecture.
#
# See cmake/install/linux/common/vk.cmake for the shared reasoning. macOS
# carries a second library in the same RT subdir: MoltenVK, the ICD
# (Apache-2), matching config/macos/common/deploy/vk.json's vk row
# (["SHARED_LIB:vulkan", "SHARED_LIB:MoltenVK"]). ICD registration stays
# the user's own environment; only the two libraries themselves are this
# unit's concern.

acpp_install_vendor_libs(STEM VK FACT "${ACPP_VK_RT_SUBDIR}" NAMES vulkan MoltenVK)
