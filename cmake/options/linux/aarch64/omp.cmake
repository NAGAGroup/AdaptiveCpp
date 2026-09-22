# OMP options - linux, aarch64.
#
# Include after core.cmake. The omp flows have no vendor unit: the CPU
# backend (`rt-backend-omp`) is internal and already in core's manifest,
# libomp is the LLVM unit's, and the host JIT is core. This file declares
# only the driver's two values. There is no discovery file.

include_guard(GLOBAL)

# ---------------------------------------------------------------------------
# Driver-only
# ---------------------------------------------------------------------------

# The OpenMP flag is the platform's, which is why the value lives here
# rather than in core. The omp link line carries no rpath to libomp: under
# the omp flows the application's own link binds libomp, so the RUNPATH is
# the application builder's.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
