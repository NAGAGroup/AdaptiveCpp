# The prolog's second part: the fetches that depend on what discovery
# found. The prolog runs discovery first, then these fetches, then the
# options files; below that the tree only adds sources and install rules.
# A fetch never feeds a find: a find must see the machine as it is, so
# this file runs after cmake/discovery.cmake, never before it.
#
# The root's CMAKE_POLICY_VERSION_MINIMUM 3.5 (needed for ocl-cxx-headers
# under cmake 4) must be set before this file runs.
#
# This file is parse-checked only: FetchContent cannot run under -P.

include_guard(GLOBAL)

# Upstream fetches only inside if(WITH_OPENCL_BACKEND), which defaults
# from the find; this follows the same rule, deferring to an explicit
# override if the caller has set one.
if((DEFINED WITH_OPENCL_BACKEND AND WITH_OPENCL_BACKEND) OR
   (NOT DEFINED WITH_OPENCL_BACKEND AND ACPP_DISCOVERED_OCL_FOUND))
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
else()
  set(ACPP_FETCHED_OCL_HEADERS_DIR "")
  set(ACPP_FETCHED_OCL_CXX_HEADERS_DIR "")
endif()
