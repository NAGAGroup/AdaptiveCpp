# Level Zero vendor install rule - linux, every architecture.
#
# See cmake/install/linux/common/cuda.cmake for the shared reasoning. A
# no-op unless ACPP_ZE_SHIPPED. A loader-only unit: ze_loader is the whole
# thing (config/linux/common/deploy/ze.json's sole external-permissive
# row); the headers are build-only (ACPP_DISCOVERED_ZE_INCLUDE_DIR,
# consumed only by the runtime target's own include directories - never a
# vendor asset), so there is no toolchain-only piece to add.

acpp_install_vendor_libs(STEM ZE FACT "${ACPP_ZE_RT_SUBDIR}" NAMES ze_loader)
