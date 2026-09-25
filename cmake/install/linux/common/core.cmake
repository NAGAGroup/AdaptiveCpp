# Core's own external vendor units - linux, every architecture: the vector
# math libraries CMakeLists.txt's own discovery finds (sleef, amath) and
# libnuma, none of which have a backend of their own - they belong to core
# (cmake/options/linux/common/core.cmake's own acpp_declare_vendor calls
# for LIBNUMA/SLEEF/AMATH), not to any WITH_*_BACKEND unit, so the root
# includes this file unconditionally rather than gating it through
# ACPP_UNITS. See config/linux/common/deploy/core.json's
# external-permissive rows for where these names came from - each a
# single library with no internal lib/include/bin split, hence no FACT.
# svml/intlc are x86_64-only and live in cmake/install/linux/x86_64/
# core.cmake instead (cmake/options/linux/x86_64/core.cmake is where
# ACPP_SVML_* is declared, arch-specific for the same reason discovery
# itself is: no SVML search on AArch64).
#
# The library short names differ from their ACPP_<STEM> stems - discovery
# (CMakeLists.txt's own find_library calls) already settled these:
# find_library(LIBSLEEF NAMES sleefgnuabi), find_library(LIBAMATH NAMES
# amath) - both under "(arm|aarch64)" only, so SLEEF/AMATH are typically
# not SHIPPED on x86_64, a no-op there, same helper either way.

acpp_install_vendor_libs(STEM SLEEF FACT "" NAMES sleefgnuabi)
acpp_install_vendor_libs(STEM AMATH FACT "" NAMES amath)
acpp_install_vendor_libs(STEM LIBNUMA FACT "" NAMES numa)
