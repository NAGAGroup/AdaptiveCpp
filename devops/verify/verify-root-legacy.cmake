# Guards against upstream's legacy root-level CMakeLists.txt logic
# returning: the vendor find_package()/find_program() shims Slice S2a
# removed, the DEFAULT_*_LINK_LINE/OMP_*/SEQUENTIAL_*/PLUGIN_LLVM_VERSION_MAJOR
# cache variables Slice S2b removed (nothing read them), the DEFAULT_TARGETS
# ordering fix Slice S2b made unnecessary, and the upstream -D name aliases
# (OMP_LINK_LINE, CUDA_LINK_LINE, ROCM_LINK_LINE, ...) Slice S2b added to
# cmake/options/common/core.cmake. Run with cmake -P:
#   cmake -P devops/verify/verify-root-legacy.cmake

get_filename_component(ACPP_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# ---------------------------------------------------------------------------
# (a) Legacy patterns must not be present in the root CMakeLists.txt.
# ---------------------------------------------------------------------------
file(READ "${ACPP_REPO_ROOT}/CMakeLists.txt" _root_text)

set(_forbidden_patterns
  "find_package\\((CUDA|HIP|Vulkan)[ )]"
  "ROCM_LIBS"
  "DEFAULT_OMP_FLAG"
  "[^_]PLUGIN_LLVM_VERSION_MAJOR"
  "set\\((OMP|SEQUENTIAL|CUDA|ROCM)_(LINK_LINE|CXX_FLAGS)"
  "HIPCC_COMPILER"
  "CLSPV_COMPILER")

foreach(_pattern ${_forbidden_patterns})
  string(REGEX MATCH "${_pattern}" _match "${_root_text}")
  if(_match)
    message(FATAL_ERROR
      "CMakeLists.txt: forbidden legacy pattern '${_pattern}' matched "
      "('${_match}') - upstream's legacy root logic appears to have "
      "returned.")
  endif()
endforeach()
message(STATUS "verify-root-legacy: no forbidden legacy pattern found")

# ---------------------------------------------------------------------------
# (b) DEFAULT_TARGETS must be computed before the options model reads it.
# ---------------------------------------------------------------------------
string(FIND "${_root_text}" "set(DEFAULT_TARGETS" _idx_default_targets)
string(FIND "${_root_text}" "include(\${ACPP_OPTIONS_DIR}/core.cmake)" _idx_include_core)

if(_idx_default_targets EQUAL -1)
  message(FATAL_ERROR "CMakeLists.txt: set(DEFAULT_TARGETS ...) not found at all")
endif()
if(_idx_include_core EQUAL -1)
  message(FATAL_ERROR "CMakeLists.txt: include(\${ACPP_OPTIONS_DIR}/core.cmake) not found at all")
endif()
if(NOT _idx_default_targets LESS _idx_include_core)
  message(FATAL_ERROR
    "CMakeLists.txt: set(DEFAULT_TARGETS ...) (offset ${_idx_default_targets}) "
    "must come before include(\${ACPP_OPTIONS_DIR}/core.cmake) (offset "
    "${_idx_include_core}), so the options model sees a real default.")
endif()
message(STATUS "verify-root-legacy: DEFAULT_TARGETS is computed before the options model reads it")

# ---------------------------------------------------------------------------
# (c) Functional check of the upstream -D name aliases and the
# ACPP_SEQUENTIAL_CXX_FLAGS default, against the real
# cmake/options/common/core.cmake. Discovery stand-ins copied from
# verify-core.cmake's setup, trimmed to what common/core.cmake alone reads.
# ---------------------------------------------------------------------------
set(CMAKE_INSTALL_LIBDIR lib)
set(CMAKE_INSTALL_BINDIR bin)
set(ACPP_LIBOMP_SOURCE_DIR "")

set(OMP_LINK_LINE "-fopenmp -lfoo")
set(ROCM_LINK_LINE "-lbar")
set(ACPP_CUDA_LINK_LINE "-lmine")
set(CUDA_LINK_LINE "-lupstream")

include(${ACPP_REPO_ROOT}/cmake/options/common/core.cmake)

function(expect_eq name expected)
  if(NOT "${${name}}" STREQUAL "${expected}")
    message(FATAL_ERROR "${name}: expected '${expected}', got '${${name}}'")
  endif()
endfunction()

expect_eq(ACPP_OMP_LINK_LINE "-fopenmp -lfoo")
expect_eq(ACPP_HIP_LINK_LINE "-lbar")
# ACPP_CUDA_LINK_LINE was already set directly; the CUDA_LINK_LINE alias
# (upstream's name) must not override it.
expect_eq(ACPP_CUDA_LINK_LINE "-lmine")
expect_eq(ACPP_SEQUENTIAL_CXX_FLAGS "-D_ENABLE_EXTENDED_ALIGNED_STORAGE")

message(STATUS "verify-root-legacy: upstream -D name aliases and ACPP_SEQUENTIAL_CXX_FLAGS default hold")

message(STATUS "verify-root-legacy: OK")
