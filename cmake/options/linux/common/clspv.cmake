# clspv options - linux, every architecture.
#
# Include after core.cmake, only when the Vulkan backend is enabled; the
# helpers and the strategy control live in core. clspv is an executable the
# JIT invokes at application run time, so it is a two-sided resource: the
# driver invokes it from the toolchain while compiling, the JIT invokes it
# from the deployment while an application runs. Two knobs (ACPP_CLSPV_SUBDIR
# plus clspv being found on PATH), everything else derived - see "Vendor
# units" in the common core file.

include_guard(GLOBAL)

acpp_declare_vendor_subdir(CLSPV clspv)
acpp_declare_vendor_root(CLSPV clspv ACPP_DISCOVERED_CLSPV_PREFIX "${ACPP_DISCOVERED_CLSPV_PREFIX}")

acpp_declare_vendor_subdir_fact(CLSPV BIN ACPP_DISCOVERED_CLSPV_BINDIR "${ACPP_DISCOVERED_CLSPV_BINDIR}")
acpp_declare_vendor_app_subdir(CLSPV clspv BIN)

# The executable itself: both strings compose {{ clspv-install-root }} with
# the bin subdir and the file name directly; the toolchain side needs no
# strategy branch, because clspv-install-root's own value already carries
# it (see acpp_declare_vendor_root). The app side does, because under
# `default` nothing is deployed and the app reads the same absolute
# location the driver used, but otherwise it reads the literal
# $ACPP_RUNTIME_ROOT the C++ runtime resolves at its own run time.
set(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
if(ACPP_DEPLOYMENT_STRATEGY STREQUAL "default")
  set(ACPP_APP_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
else()
  set(ACPP_APP_CLSPV "\$ACPP_RUNTIME_ROOT/{{ clspv-subdir }}/{{ clspv-bin-subdir }}/clspv")
endif()
