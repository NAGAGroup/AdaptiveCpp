# OMP options - macos, every architecture.
#
# Include after core.cmake. The omp flows have no vendor unit: the CPU
# backend (`rt-backend-omp`) is internal and already in core's manifest,
# libomp is the LLVM unit's, and the host JIT is core. This file declares
# only the driver's two values. There is no discovery file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

# On macOS clang does not find libomp on its own, so the link line names
# the directory. The multipass exemption still applies to rpath.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp -L{{ libomp-path }} -lomp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
