# clspv options - macos, every architecture.
#
# Include after core.cmake, only when the Vulkan backend is enabled; the
# helpers and the strategy control live in core. clspv is an executable the
# JIT invokes at application run time, so it is a two-sided resource: the
# driver invokes it from the toolchain while compiling, the JIT invokes it
# from the deployment while an application runs. Two knobs (ACPP_CLSPV_SUBDIR
# plus clspv being found on PATH), everything else derived - see "Vendor
# units" in the common core file.

include_guard(GLOBAL)

acpp_declare_vendor(CLSPV clspv permissive)
acpp_declare_vendor_root(CLSPV clspv ACPP_DISCOVERED_CLSPV_PREFIX "${ACPP_DISCOVERED_CLSPV_PREFIX}")

acpp_declare_vendor_subdir_fact(CLSPV BIN ACPP_DISCOVERED_CLSPV_BINDIR "${ACPP_DISCOVERED_CLSPV_BINDIR}")
acpp_declare_vendor_app_dir(CLSPV clspv BIN)

# The executable itself, same reasoning as linux's clspv.cmake.
set(ACPP_TOOLCHAIN_CLSPV "{{ clspv-install-root }}/{{ clspv-bin-subdir }}/clspv")
if(ACPP_CLSPV_SHIPPED)
  acpp_relative_from_rt_libdir(_acpp_clspv_rel "${ACPP_CLSPV_SUBDIR}")
  acpp_join_relative(_acpp_clspv_rel "${_acpp_clspv_rel}" "${ACPP_CLSPV_BIN_SUBDIR}")
  if("${_acpp_clspv_rel}" STREQUAL "")
    set(ACPP_APP_CLSPV "\$ACPP_RT_LIB_DIR/clspv")
  else()
    set(ACPP_APP_CLSPV "\$ACPP_RT_LIB_DIR/${_acpp_clspv_rel}/clspv")
  endif()
  unset(_acpp_clspv_rel)
else()
  acpp_join_absolute(_acpp_clspv_dir "${ACPP_CLSPV_APP_ROOT}" "${ACPP_CLSPV_BIN_SUBDIR}")
  if("${_acpp_clspv_dir}" STREQUAL "")
    set(ACPP_APP_CLSPV "")
  else()
    set(ACPP_APP_CLSPV "${_acpp_clspv_dir}/clspv")
  endif()
  unset(_acpp_clspv_dir)
endif()
