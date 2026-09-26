# The shipped matrix: a permissive vendor (OCL) alongside a nonpermissive
# one (CUDA), across all three strategies, run with cmake -P:
#   cmake -P devops/verify/verify-strategy-matrix.cmake
#
# verify-strategy-cuda.cmake already proves CUDA's own not-shipped/shipped/
# gated behaviour end to end; this harness adds the piece that needs a
# second, permissive vendor alongside it to prove: full-permissive-only
# ships a permissive vendor but not a nonpermissive one, and needs no gate
# at all to do it (unlike plain "full" with a nonpermissive vendor present).
#
#   managed:              CUDA not shipped, OCL not shipped.
#   full-permissive-only:  CUDA not shipped, OCL shipped - no gate set,
#                          and the run still succeeds (CUDA never asks for
#                          one, since it is never shipped under this
#                          strategy).
#   full (gated):          both shipped (already covered by
#                          verify-strategy-cuda.cmake; not repeated here).
#
# Runs cuda.cmake/ocl.cmake in a child process (verify-strategy-matrix-
# inner.cmake) for the same include_guard(GLOBAL) reason verify-strategy-
# cuda.cmake's own inner file documents.

set(_inner "${CMAKE_CURRENT_LIST_DIR}/verify-strategy-matrix-inner.cmake")

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

function(run_strategy strategy out_var)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -D "ACPP_DEPLOYMENT_STRATEGY=${strategy}" -P "${_inner}"
    OUTPUT_VARIABLE _out ERROR_VARIABLE _out2 RESULT_VARIABLE _res)
  if(NOT _res EQUAL 0)
    message(FATAL_ERROR "strategy '${strategy}' inner run failed:\n${_out}\n${_out2}")
  endif()
  set(${out_var} "${_out}${_out2}" PARENT_SCOPE)
endfunction()

function(extract_result blob key out_var)
  string(REGEX MATCH "RESULT:${key}=([^\r\n]*)" _m "${blob}")
  if(NOT _m)
    message(FATAL_ERROR "could not find RESULT:${key}= in child output:\n${blob}")
  endif()
  set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# managed: neither vendor is shipped.
# ---------------------------------------------------------------------------

run_strategy("managed" _managed_out)
extract_result("${_managed_out}" "ACPP_CUDA_SHIPPED" _managed_cuda_shipped)
extract_result("${_managed_out}" "ACPP_OCL_SHIPPED" _managed_ocl_shipped)
expect_eq(_managed_cuda_shipped "OFF")
expect_eq(_managed_ocl_shipped "OFF")
extract_result("${_managed_out}" "ACPP_APP_CUDA_LIBDEVICE_DIR" _managed_cuda_dir)
expect_eq(_managed_cuda_dir "/usr/local/cuda-12.9/nvvm/libdevice")
extract_result("${_managed_out}" "ACPP_APP_OCL_RT_DIR" _managed_ocl_dir)
expect_eq(_managed_ocl_dir "/usr/lib/x86_64-linux-gnu")

message(STATUS "matrix: managed - CUDA not shipped (${_managed_cuda_dir}), OCL not shipped (${_managed_ocl_dir})")

# ---------------------------------------------------------------------------
# full-permissive-only, no gate set at all: OCL (permissive) ships, CUDA
# (nonpermissive) does not - and the run must still succeed, proving no
# gate is needed for this strategy (CUDA never asks for one here).
# ---------------------------------------------------------------------------

run_strategy("full-permissive-only" _fpo_out)
extract_result("${_fpo_out}" "ACPP_CUDA_SHIPPED" _fpo_cuda_shipped)
extract_result("${_fpo_out}" "ACPP_OCL_SHIPPED" _fpo_ocl_shipped)
expect_eq(_fpo_cuda_shipped "OFF")
expect_eq(_fpo_ocl_shipped "ON")
extract_result("${_fpo_out}" "ACPP_APP_CUDA_LIBDEVICE_DIR" _fpo_cuda_dir)
expect_eq(_fpo_cuda_dir "/usr/local/cuda-12.9/nvvm/libdevice")
extract_result("${_fpo_out}" "ACPP_APP_OCL_RT_DIR" _fpo_ocl_dir)
expect_eq(_fpo_ocl_dir "\$ACPP_RT_LIB_DIR/hipSYCL/ext/ocl/lib/x86_64-linux-gnu")

message(STATUS "matrix: full-permissive-only, no gate - OCL shipped (${_fpo_ocl_dir}), CUDA still not (${_fpo_cuda_dir})")

message(STATUS "verify-strategy-matrix: all checks passed")
