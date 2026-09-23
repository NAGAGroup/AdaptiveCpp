# Vulkan options - macos, every architecture.
#
# Include after core.cmake, only when the Vulkan backend is enabled; the
# helpers and the strategy control live in core. A loader-only unit: the
# unit is the Vulkan loader in the vendor's own library directory, nothing
# else. Vulkan has no multipass flow, so the driver passes nothing. Two
# knobs (ACPP_VK_SUBDIR plus the loader/header/SPIRV-Tools hints),
# everything else derived - see "Vendor units" in the common core file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(VK vk)
acpp_declare_vendor_root(VK vk ACPP_DISCOVERED_VK_PREFIX "${ACPP_DISCOVERED_VK_PREFIX}")

acpp_declare_vendor_subdir_fact(VK RT ACPP_DISCOVERED_VK_LIBDIR "${ACPP_DISCOVERED_VK_LIBDIR}")
acpp_declare_vendor_app_subdir(VK vk RT)

# The runtime reaches the loader through DT_NEEDED and RUNPATH; nothing is
# read at run time. Vulkan has no multipass flow; the driver passes nothing.
