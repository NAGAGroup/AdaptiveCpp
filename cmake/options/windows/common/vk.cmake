# Vulkan options - windows, every architecture.
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

# The Vulkan SDK on Windows ships only the import library; the loader
# vulkan-1.dll lives in System32, installed by graphics drivers or the
# Vulkan runtime installer, and the loader's maintainers advise against
# bundling it. The Vulkan unit therefore deploys nothing on Windows, has no
# DLL directory resource, and the runtime reaches the machine's loader as
# it would a driver. The subdir and root are kept for uniform shape.
