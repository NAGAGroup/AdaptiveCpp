# Exercises cmake/discovery/hip-layout.cmake's probes directly, against a
# scratch directory tree shaped like every layout the HIP discovery
# accepts, run with cmake -P:
#   cmake -P devops/verify/verify-hip-layouts.cmake
#
# find_package(hip) creates imported targets (unavailable in script mode),
# so the actual discovery/hip.cmake cannot be exercised end to end here;
# this harness covers the probe functions it delegates to instead.

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include(${ACPP_REPO_ROOT}/cmake/discovery/hip-layout.cmake)

if(DEFINED ENV{TMPDIR})
  set(_scratch_base "$ENV{TMPDIR}")
else()
  set(_scratch_base "/tmp")
endif()
set(_r "${_scratch_base}/acpp-verify-hip-layouts")
file(REMOVE_RECURSE "${_r}")

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# (a) TheRock: bitcode under lib/llvm/amdgcn/bitcode, sysdeps present.
# ---------------------------------------------------------------------------
unset(ROCM_DEVICE_LIBS_PATH)
file(MAKE_DIRECTORY "${_r}/therock/lib/llvm/amdgcn/bitcode")
file(TOUCH "${_r}/therock/lib/llvm/amdgcn/bitcode/ockl.bc")
file(MAKE_DIRECTORY "${_r}/therock/lib/rocm_sysdeps/lib")

acpp_hip_probe_bitcode(_bc "${_r}/therock")
expect_eq(_bc "${_r}/therock/lib/llvm/amdgcn/bitcode")

acpp_hip_probe_sysdeps(_sd "${_r}/therock/lib")
expect_eq(_sd "${_r}/therock/lib/rocm_sysdeps/lib")

message(STATUS "verify-hip-layouts: TheRock layout found")

# ---------------------------------------------------------------------------
# (b) Classic ROCm: bitcode directly under amdgcn/bitcode, no sysdeps.
# ---------------------------------------------------------------------------
unset(ROCM_DEVICE_LIBS_PATH)
file(MAKE_DIRECTORY "${_r}/classic/amdgcn/bitcode")
file(TOUCH "${_r}/classic/amdgcn/bitcode/ockl.bc")

acpp_hip_probe_bitcode(_bc "${_r}/classic")
expect_eq(_bc "${_r}/classic/amdgcn/bitcode")

acpp_hip_probe_sysdeps(_sd "${_r}/classic/lib")
expect_eq(_sd "")

message(STATUS "verify-hip-layouts: classic ROCm layout found, no sysdeps")

# ---------------------------------------------------------------------------
# (c) ROCm 7.2+: bitcode in the clang resource directory, highest version
# first - a lower-numbered sibling with no ockl.bc must not win by
# accident, and must not stop the probe either.
# ---------------------------------------------------------------------------
unset(ROCM_DEVICE_LIBS_PATH)
file(MAKE_DIRECTORY "${_r}/r72/lib/llvm/lib/clang/22/lib/amdgcn/bitcode")
file(TOUCH "${_r}/r72/lib/llvm/lib/clang/22/lib/amdgcn/bitcode/ockl.bc")
file(MAKE_DIRECTORY "${_r}/r72/lib/llvm/lib/clang/9/lib/amdgcn/bitcode")

acpp_hip_probe_bitcode(_bc "${_r}/r72")
expect_eq(_bc "${_r}/r72/lib/llvm/lib/clang/22/lib/amdgcn/bitcode")

message(STATUS "verify-hip-layouts: ROCm 7.2+ clang resource directory found, highest version wins")

# ---------------------------------------------------------------------------
# (d) Upstream's -DROCM_DEVICE_LIBS_PATH overrides the probe, even against
# a prefix (reused from case b) that would otherwise resolve differently.
# ---------------------------------------------------------------------------
file(MAKE_DIRECTORY "${_r}/custom")
file(TOUCH "${_r}/custom/ockl.bc")
set(ROCM_DEVICE_LIBS_PATH "${_r}/custom")

acpp_hip_probe_bitcode(_bc "${_r}/classic")
expect_eq(_bc "${_r}/custom")

unset(ROCM_DEVICE_LIBS_PATH)
message(STATUS "verify-hip-layouts: -DROCM_DEVICE_LIBS_PATH overrides the probe")

# ---------------------------------------------------------------------------
# (e) None of the layouts match: empty result, non-empty TRIED.
# ---------------------------------------------------------------------------
unset(ROCM_DEVICE_LIBS_PATH)
file(MAKE_DIRECTORY "${_r}/empty")

acpp_hip_probe_bitcode(_bc "${_r}/empty")
expect_eq(_bc "")
if("${_bc_TRIED}" STREQUAL "")
  message(FATAL_ERROR "_bc_TRIED should be non-empty when nothing was found")
endif()

message(STATUS "verify-hip-layouts: no layout matches -> empty result, TRIED lists what was tried")

file(REMOVE_RECURSE "${_r}")

message(STATUS "verify-hip-layouts: OK")
