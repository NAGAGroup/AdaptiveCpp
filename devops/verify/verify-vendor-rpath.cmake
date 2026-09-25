# Backends' rpaths to shipped vendors (cmake/acpp-vendor-rpath.cmake), run
# with cmake -P:
#   cmake -P devops/verify/verify-vendor-rpath.cmake
#
# acpp_vendor_rpath_entry is a pure function (no install(), nothing this
# harness needs a child process for) - tested directly against lib-relative
# values that match the real defaults (ACPP_<STEM>_SUBDIR's own default
# shape, "<CMAKE_INSTALL_LIBDIR>/hipSYCL/ext/<lower>", and every backend's
# own FROM, "<CMAKE_INSTALL_LIBDIR>/hipSYCL"):
#
#   (1) Shipped CUDA, default subdir, RT "lib64" -> $ORIGIN/ext/cuda/lib64.
#   (2) Conda-shaped CUDA (subdir "", RT "targets/x86_64-linux/lib") ->
#       $ORIGIN/../../targets/x86_64-linux/lib.
#   (3) Not shipped -> "".
#   (4) LIBOMP, no fact, default subdir -> $ORIGIN/ext/libomp.
#   (5) Same as (1), but APPLE -> @loader_path/ext/cuda/lib64 (parse-checked
#       here, exercised for real only on macOS - same convention as every
#       other APPLE branch in this codebase).

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/acpp-vendor-rpath.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# (1) Shipped CUDA, default subdir, RT "lib64", FROM "lib/hipSYCL".
# ---------------------------------------------------------------------------

set(ACPP_CUDA_SHIPPED ON)
set(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")

acpp_vendor_rpath_entry(_r1 STEM CUDA FACT "lib64" FROM "lib/hipSYCL")
expect_eq(_r1 "$ORIGIN/ext/cuda/lib64")

message(STATUS "verify-vendor-rpath: shipped CUDA, default subdir -> \$ORIGIN/ext/cuda/lib64")

# ---------------------------------------------------------------------------
# (2) Conda-shaped: subdir "" (installs straight at the prefix root), RT
# "targets/x86_64-linux/lib".
# ---------------------------------------------------------------------------

set(ACPP_CUDA_SUBDIR "")

acpp_vendor_rpath_entry(_r2 STEM CUDA FACT "targets/x86_64-linux/lib" FROM "lib/hipSYCL")
expect_eq(_r2 "$ORIGIN/../../targets/x86_64-linux/lib")

message(STATUS "verify-vendor-rpath: conda-shaped CUDA (subdir \"\") -> \$ORIGIN/../../targets/x86_64-linux/lib")

# ---------------------------------------------------------------------------
# (3) Not shipped -> "".
# ---------------------------------------------------------------------------

set(ACPP_CUDA_SHIPPED OFF)

acpp_vendor_rpath_entry(_r3 STEM CUDA FACT "lib64" FROM "lib/hipSYCL")
expect_eq(_r3 "")

message(STATUS "verify-vendor-rpath: not shipped -> empty entry")

# ---------------------------------------------------------------------------
# (4) LIBOMP, no fact, default subdir.
# ---------------------------------------------------------------------------

set(ACPP_LIBOMP_SHIPPED ON)
set(ACPP_LIBOMP_SUBDIR "lib/hipSYCL/ext/libomp")

acpp_vendor_rpath_entry(_r4 STEM LIBOMP FACT "" FROM "lib/hipSYCL")
expect_eq(_r4 "$ORIGIN/ext/libomp")

message(STATUS "verify-vendor-rpath: LIBOMP, no fact -> \$ORIGIN/ext/libomp")

# ---------------------------------------------------------------------------
# (5) Same as (1), but APPLE.
# ---------------------------------------------------------------------------

set(ACPP_CUDA_SHIPPED ON)
set(ACPP_CUDA_SUBDIR "lib/hipSYCL/ext/cuda")
set(APPLE TRUE)

acpp_vendor_rpath_entry(_r5 STEM CUDA FACT "lib64" FROM "lib/hipSYCL")
expect_eq(_r5 "@loader_path/ext/cuda/lib64")

unset(APPLE)

message(STATUS "verify-vendor-rpath: APPLE uses @loader_path -> @loader_path/ext/cuda/lib64")

# ---------------------------------------------------------------------------
# (6) acpp_add_vendor_rpaths guards itself against a target that does not
# exist (a disabled backend's add_library() never ran) - set_property(
# TARGET ...) on a nonexistent target is a hard error, so this has to be
# checked before touching ENTRIES at all, and this call would fail loudly
# if it were not. A stem with no ACPP_<STEM>_SHIPPED at all (an undeclared
# vendor) never gets this far in that case, but is otherwise already
# handled the same way acpp_vendor_rpath_entry's own falsy check on an
# undefined variable is - checks (1)-(5) above already exercise that
# function directly.
# ---------------------------------------------------------------------------

acpp_add_vendor_rpaths(this-target-does-not-exist FROM "lib/hipSYCL" ENTRIES CUDA:RT UNDECLAREDVENDOR)

message(STATUS "verify-vendor-rpath: acpp_add_vendor_rpaths skips a missing target without erroring")

message(STATUS "verify-vendor-rpath: all checks passed")
