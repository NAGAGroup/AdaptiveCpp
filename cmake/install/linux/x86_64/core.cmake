# Core's own external vendor units - linux, x86_64 only: SVML/INTLC, the
# vector math library pair CMakeLists.txt's own discovery finds only off
# AArch64 (find_library(LIBSVML NAMES svml), find_library(LIBINTLC NAMES
# intlc), both under "NOT CMAKE_SYSTEM_PROCESSOR MATCHES (arm|aarch64)").
# See cmake/install/linux/common/core.cmake for the shared reasoning and
# config/linux/x86_64/deploy/core.json's external-nonpermissive row, which
# carries both libraries at the same svml-install-root/svml-subdir - no
# FACT, one vendor unit, two files.

acpp_install_vendor_libs(STEM SVML FACT "" NAMES svml intlc)
