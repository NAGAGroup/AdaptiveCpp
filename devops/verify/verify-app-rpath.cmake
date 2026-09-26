# Applications' install rpath (cmake/acpp-vendor-rpath.cmake's
# acpp_app_install_rpath, Commit 6), run with cmake -P:
#   cmake -P devops/verify/verify-app-rpath.cmake
#
# A pure function (no install(), nothing this harness needs a child
# process for) - tested directly against a handful of hand-set
# ACPP_<STEM>_* variables, the same way verify-vendor-rpath.cmake tests
# acpp_vendor_rpath_entry itself:
#
#   (1) managed -> "".
#   (2) full, CUDA shipped (default subdir, RT "lib64") and LIBOMP shipped,
#       NVHPC not even declared -> exactly
#       "$ORIGIN/../lib;$ORIGIN/../lib/hipSYCL/ext/cuda/lib64;
#        $ORIGIN/../lib/hipSYCL/ext/libomp".
#   (3) Conda-shaped CUDA (subdir "", RT "targets/x86_64-linux/lib") ->
#       contains "$ORIGIN/../targets/x86_64-linux/lib".
#   (4) WIN32 -> "" even under full.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-vendor-rpath.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

set(CMAKE_INSTALL_BINDIR "bin")
set(CMAKE_INSTALL_LIBDIR "lib")

# ---------------------------------------------------------------------------
# (1) managed -> "".
# ---------------------------------------------------------------------------

set(ACPP_DEPLOYMENT_STRATEGY "managed")
set(ACPP_CUDA_SHIPPED ON)
set(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")
set(ACPP_CUDA_RT_SUBDIR "lib64")
set(ACPP_LIBOMP_SHIPPED ON)
set(ACPP_LIBOMP_SUBDIR "lib/hipSYCL/ext/libomp")

acpp_app_install_rpath(_r1)
expect_eq(_r1 "")

message(STATUS "verify-app-rpath: managed -> \"\"")

# ---------------------------------------------------------------------------
# (2) full, CUDA + LIBOMP shipped, NVHPC never declared at all.
# ---------------------------------------------------------------------------

set(ACPP_DEPLOYMENT_STRATEGY "full")

acpp_app_install_rpath(_r2)
expect_eq(_r2 "$ORIGIN/../lib;$ORIGIN/../lib/hipSYCL/ext/cuda/lib64;$ORIGIN/../lib/hipSYCL/ext/libomp")

message(STATUS "verify-app-rpath: full, CUDA+LIBOMP shipped -> \$ORIGIN/../lib;\$ORIGIN/../lib/hipSYCL/ext/cuda/lib64;\$ORIGIN/../lib/hipSYCL/ext/libomp")

# ---------------------------------------------------------------------------
# (3) Conda-shaped CUDA: subdir "" (installs straight at the prefix root),
# RT "targets/x86_64-linux/lib".
# ---------------------------------------------------------------------------

set(ACPP_CUDA_SUBDIR "")
set(ACPP_CUDA_RT_SUBDIR "targets/x86_64-linux/lib")

acpp_app_install_rpath(_r3)
list(FIND _r3 "$ORIGIN/../targets/x86_64-linux/lib" _r3_idx)
if(_r3_idx EQUAL -1)
  message(FATAL_ERROR "verify-app-rpath: conda-shaped CUDA entry missing from '${_r3}'")
endif()

message(STATUS "verify-app-rpath: conda-shaped CUDA (subdir \"\") -> contains \$ORIGIN/../targets/x86_64-linux/lib")

# Restore for the next case.
set(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")
set(ACPP_CUDA_RT_SUBDIR "lib64")

# ---------------------------------------------------------------------------
# (4) WIN32 -> "" even under full.
# ---------------------------------------------------------------------------

set(WIN32 TRUE)

acpp_app_install_rpath(_r4)
expect_eq(_r4 "")

unset(WIN32)

message(STATUS "verify-app-rpath: WIN32 -> \"\" even under full")

message(STATUS "verify-app-rpath: all checks passed")
