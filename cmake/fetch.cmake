# The prolog's first part: every fetch the build needs, run before
# discovery so that a find can see what was fetched. Below discovery and
# the options files, the tree only adds sources and install rules; nothing
# below this point may fetch.
#
# The root's CMAKE_POLICY_VERSION_MINIMUM 3.5 (needed for ocl-cxx-headers
# under cmake 4) must be set before this file runs.
#
# This file is parse-checked only: FetchContent cannot run under -P.

include_guard(GLOBAL)

# Upstream's OpenCL gate, unchanged: the fetch is skipped once
# WITH_SSCP_COMPILER or WITH_OPENCL_BACKEND is known and false. Both start
# undefined, so the first configure always fetches; a later configure that
# has turned either off skips it.
if((DEFINED WITH_SSCP_COMPILER AND NOT WITH_SSCP_COMPILER) OR
   (DEFINED WITH_OPENCL_BACKEND AND NOT WITH_OPENCL_BACKEND))
  set(ACPP_FETCHED_OCL_HEADERS_DIR "")
  set(ACPP_FETCHED_OCL_CXX_HEADERS_DIR "")
else()
  include(FetchContent)

  FetchContent_Declare(ocl-headers
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenCL-Headers
    GIT_TAG 265df85aec478d14a5c5880d7bb92d7dd52714ef
  )
  FetchContent_MakeAvailable(ocl-headers)
  set(ACPP_FETCHED_OCL_HEADERS_DIR "${ocl-headers_SOURCE_DIR}")

  FetchContent_Declare(ocl-cxx-headers
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenCL-CLHPP
    GIT_TAG 67d100e70612341707725b6648ccca4c10b0dc31
  )
  FetchContent_MakeAvailable(ocl-cxx-headers)
  set(ACPP_FETCHED_OCL_CXX_HEADERS_DIR "${ocl-cxx-headers_SOURCE_DIR}/include")
endif()
