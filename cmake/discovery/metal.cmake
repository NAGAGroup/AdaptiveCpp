# Metal backend discovery.
#
# Loaded by cmake/discovery.cmake after the core half; exports
# ACPP_DISCOVERED_METAL_*. Not found is the normalized empty string.
#
# metal-cpp is a header-only wrapper from developer.apple.com, build-only:
# the runtime compiles MSL through the system Metal framework at run time
# (MTL::Device::newLibrary(source)), so nothing external is deployed and
# the unit has no vendor library.

include_guard(GLOBAL)

find_path(METAL_INCLUDE_DIR NAMES Metal/Metal.hpp
  HINTS $ENV{METAL_INCLUDE_DIR} ${METAL_INCLUDE_DIR})

if(METAL_INCLUDE_DIR AND NOT "${METAL_INCLUDE_DIR}" MATCHES "-NOTFOUND$")
  set(ACPP_DISCOVERED_METAL_FOUND ON)
  # Build-only: consumed by the runtime target's include directories, never
  # written to the configuration.
  set(ACPP_DISCOVERED_METAL_INCLUDE_DIR "${METAL_INCLUDE_DIR}")
else()
  set(ACPP_DISCOVERED_METAL_FOUND OFF)
  set(ACPP_DISCOVERED_METAL_INCLUDE_DIR "")
endif()
