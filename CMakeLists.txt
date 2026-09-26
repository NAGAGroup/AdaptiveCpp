cmake_minimum_required(VERSION 3.10)

if(POLICY CMP0074) # Since CMake 3.12
  cmake_policy(SET CMP0074 NEW) # Don't complain about using OpenMP_ROOT...
endif()
if (POLICY CMP0144) # Since CMake 3.27
  cmake_policy(SET CMP0144 NEW)
endif()

if(CMAKE_VERSION VERSION_GREATER_EQUAL 4.0)
  # Prevent CMake >= 4.0 from failing when configuring, e.g. the ocl-cxx-headers.
  set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
endif()

set(ACPP_VERSION_MAJOR 25)
set(ACPP_VERSION_MINOR 10)
set(ACPP_VERSION_PATCH 0)

execute_process(
        COMMAND git status
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        RESULT_VARIABLE GIT_STATUS
)

if(NOT ACPP_VERSION_SUFFIX)
  # With a release tarball, "git status" will fail (return non zero)
  if(GIT_STATUS)
    set(ACPP_VERSION_SUFFIX "")
  else()
    # Get the latest abbreviated commit hash of the working branch
    execute_process(
      COMMAND git log -1 --format=%h
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE ACPP_GIT_COMMIT_HASH
      RESULT_VARIABLE GIT_HASH_RETURN_CODE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    # git branch
    execute_process(
      COMMAND git rev-parse --abbrev-ref HEAD
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE ACPP_GIT_BRANCH
      RESULT_VARIABLE GIT_BRANCH_RETURN_CODE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    # date of commit
    execute_process(COMMAND git show -s --format=%cd --date=short HEAD
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE ACPP_GIT_DATE
      RESULT_VARIABLE GIT_DATE_RETURN_CODE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    # Convert YYYY-MM-DD to YYYYMMDD
    # We can't use --date=format:%Y%m%d to be compatible with git pre-2.6
    string(REPLACE "-" "" ACPP_GIT_DATE ${ACPP_GIT_DATE})
    # check whether there are local changes
    execute_process(COMMAND git diff-index --name-only HEAD
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE ACPP_LOCAL_CHANGES
      RESULT_VARIABLE GIT_LOCAL_CHANGES_RETURN_CODE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if (GIT_HASH_RETURN_CODE EQUAL 0 AND GIT_BRANCH_RETURN_CODE EQUAL 0 AND
        GIT_DATE_RETURN_CODE EQUAL 0 AND GIT_LOCAL_CHANGES_RETURN_CODE EQUAL 0)

      if(NOT "${ACPP_LOCAL_CHANGES}" STREQUAL "")
        set(DIRTY_STR ".dirty")
      else()
        set(DIRTY_STR "")
      endif()

      set(ACPP_VERSION_SUFFIX "+git.${ACPP_GIT_COMMIT_HASH}.${ACPP_GIT_DATE}.branch.${ACPP_GIT_BRANCH}${DIRTY_STR}")
    endif()
  endif()
endif()

if(NOT DEFINED LLVM_MAIN_SRC_DIR)
  project(hipSYCL VERSION ${ACPP_VERSION_MAJOR}.${ACPP_VERSION_MINOR}.${ACPP_VERSION_PATCH})

  set(ACPP_LLVM_COMPONENT OFF CACHE BOOL "AdaptiveCpp is being built as a component of LLVM")
  set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS false)
else()
  set(ACPP_LLVM_COMPONENT ON CACHE BOOL "AdaptiveCpp is being built as a component of LLVM")
  set(LLVM_SUBPROJECT_TITLE "AdaptiveCpp")
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS true)
  else()
    set(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS false)
  endif()
endif()

set(ACPP_EXPERIMENTAL_LLVM OFF CACHE BOOL "Whether to allow building AdaptiveCpp against unsupported LLVM versions")

set(ACPP_SUBPROJECT_PARALLEL_JOBS "1" CACHE STRING "Specifies the number of parallel jobs to use when building subprojects")
if(NOT ACPP_SUBPROJECT_PARALLEL_JOBS MATCHES "^[1-9][0-9]*$")
  message(SEND_ERROR "ACPP_SUBPROJECT_PARALLEL_JOBS must be a positive integer.")
endif()

set(HIPSYCL_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(ACPP_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(ACPP_BINARY_ROOT "${CMAKE_CURRENT_BINARY_DIR}")

# Install directory conventions, included early so CMAKE_INSTALL_LIBDIR is
# available to every consumer.
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT ACPP_LLVM_COMPONENT)
  set(CMAKE_BUILD_TYPE Release)
endif()

if(NOT HIPSYCL_DEBUG_LEVEL)
  if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(HIPSYCL_DEBUG_LEVEL 3 CACHE STRING
      "Choose the debug level, options are: 0 (no debug), 1 (print errors), 2 (also print warnings), 3 (also print general information)"
  )
  else()
    set(HIPSYCL_DEBUG_LEVEL 2 CACHE STRING
      "Choose the debug level, options are: 0 (no debug), 1 (print errors), 2 (also print warnings), 3 (also print general information)"
  )
  endif()
endif()

# Our own cmake modules (FindFilesystem)
list(INSERT CMAKE_MODULE_PATH 0 "${ACPP_SOURCE_ROOT}/cmake/")

#set(WITH_CUDA_NVCXX_ONLY FALSE CACHE BOOL "(Deprecated) Whether to target CUDA exclusively with nvc++")

if((APPLE OR WIN32) AND ACPP_LLVM_COMPONENT)
  set(DEFAULT_COMPILER_FEATURES_ENABLED true)
  set(ACPP_COMPILER_FEATURE_PROFILE "full" CACHE STRING "The level of AdaptiveCpp compiler features to enable. If not set to 'full', AdaptiveCpp will run in a degraded mode that may have implications for certain functionalities or performance in certain cases.")
  if(WIN32)
    add_definitions(-DWIN32_LEAN_AND_MEAN -DNOMINMAX -D_USE_MATH_DEFINES)
  endif()
elseif(APPLE OR WIN32)
  set(DEFAULT_COMPILER_FEATURES_ENABLED false)
  set(ACPP_COMPILER_FEATURE_PROFILE "none" CACHE STRING "The level of AdaptiveCpp compiler features to enable. If not set to 'full', AdaptiveCpp will run in a degraded mode that may have implications for certain functionalities or performance in certain cases.")
else()
  set(DEFAULT_COMPILER_FEATURES_ENABLED true)
  set(ACPP_COMPILER_FEATURE_PROFILE "full" CACHE STRING "The level of AdaptiveCpp compiler features to enable. If not set to 'full', AdaptiveCpp will run in a degraded mode that may have implications for certain functionalities or performance in certain cases.")
endif()
set_property(CACHE ACPP_COMPILER_FEATURE_PROFILE PROPERTY STRINGS full minimal none)


if (DEFINED WITH_SSCP_COMPILER OR DEFINED WITH_STDPAR_COMPILER OR DEFINED WITH_ACCELERATED_CPU OR DEFINED WITH_CUDA_NVCXX_ONLY)
  message(DEPRECATION "WITH_SSCP_COMPILER, WITH_STDPAR_COMPILER, WITH_ACCELERATED_CPU and WITH_CUDA_NVCXX_ONLY are deprecated and will be removed in a future version; please use ACPP_COMPILER_FEATURE_PROFILE instead.")
  set(ACPP_COMPILER_FEATURE_PROFILE "custom-deprecated")
endif()


set(ACPP_CUSTOM_PROFILE_WITH_SSCP_COMPILER ${DEFAULT_COMPILER_FEATURES_ENABLED} CACHE INTERNAL "(deprecated) custom profile")
set(ACPP_CUSTOM_PROFILE_WITH_STDPAR_COMPILER ${DEFAULT_COMPILER_FEATURES_ENABLED} CACHE INTERNAL "(deprecated) custom profile")
set(ACPP_CUSTOM_PROFILE_WITH_ACCELERATED_CPU ${DEFAULT_COMPILER_FEATURES_ENABLED} CACHE INTERNAL "(deprecated) custom profile")

if(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "full")
  set(WITH_SSCP_COMPILER true)
  if(APPLE OR WIN32)
    set(WITH_STDPAR_COMPILER false)
  else()
    set(WITH_STDPAR_COMPILER true)
  endif()
  set(WITH_ACCELERATED_CPU true)
elseif(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "minimal")
  set(WITH_SSCP_COMPILER false)
  set(WITH_STDPAR_COMPILER false)
  set(WITH_ACCELERATED_CPU false)
elseif(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "none")
  # CUDA_NVCXX is handled further down.
  set(WITH_SSCP_COMPILER false)
  set(WITH_STDPAR_COMPILER false)
  set(WITH_ACCELERATED_CPU false)
elseif(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "custom-deprecated")
  if(DEFINED WITH_SSCP_COMPILER)
    set(ACPP_CUSTOM_PROFILE_WITH_SSCP_COMPILER ${WITH_SSCP_COMPILER} CACHE INTERNAL "(deprecated) custom profile")
  endif()
  if(DEFINED WITH_STDPAR_COMPILER)
    set(ACPP_CUSTOM_PROFILE_WITH_STDPAR_COMPILER ${WITH_STDPAR_COMPILER} CACHE INTERNAL "(deprecated) custom profile")
  endif()
  if(DEFINED WITH_ACCELERATED_CPU)
    set(ACPP_CUSTOM_PROFILE_WITH_ACCELERATED_CPU ${WITH_ACCELERATED_CPU} CACHE INTERNAL "(deprecated) custom profile")
  endif()

  # Ensure that these argument do not enter cache, otherwise the if(defined) checks above
  # will no longer work.
  unset(WITH_SSCP_COMPILER CACHE)
  unset(WITH_STDPAR_COMPILER CACHE)
  unset(WITH_ACCELERATED_CPU CACHE)

  set(WITH_SSCP_COMPILER ${ACPP_CUSTOM_PROFILE_WITH_SSCP_COMPILER})
  set(WITH_STDPAR_COMPILER ${ACPP_CUSTOM_PROFILE_WITH_STDPAR_COMPILER})
  set(WITH_ACCELERATED_CPU ${ACPP_CUSTOM_PROFILE_WITH_ACCELERATED_CPU})


  message(DEPRECATION "Configuring DEPRECATED custom compiler feature profile with SSCP=${WITH_SSCP_COMPILER}, stdpar=${WITH_STDPAR_COMPILER}, accelerated cpu=${WITH_ACCELERATED_CPU}")
else()
  message(SEND_ERROR "Invalid value for ACPP_COMPILER_FEATURE_PROFILE: '${ACPP_COMPILER_FEATURE_PROFILE}'. Allowed values are: full, minimal, none")
endif()


message(STATUS "Building with compiler feature profile: ${ACPP_COMPILER_FEATURE_PROFILE}")

##########################################################
## Backend discovery and enablement.
##
## Each backend's cmake/discovery/<vendor>.cmake runs unless the builder
## explicitly turned that backend off, and WITH_<X>_BACKEND defaults from
## what discovery found. Upstream's -D spellings still steer the finds:
## CUDA_TOOLKIT_ROOT_DIR/CUDAToolkit_ROOT, ROCM_PATH/hip_ROOT,
## NVCXX_COMPILER, OpenCL_LIBRARY. The per-unit includes further down
## (the ACPP_UNITS block) are no-ops under each file's include_guard.
##
## OpenCL and Level Zero are only looked for when the SSCP compiler is on,
## as upstream only looked for OpenCL then. Level Zero defaults ON when its
## loader is found. Vulkan and Metal stay OFF unless requested.
##########################################################

if(NOT DEFINED WITH_CUDA_BACKEND OR WITH_CUDA_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/cuda.cmake)
else()
  set(ACPP_DISCOVERED_CUDA_FOUND OFF)
endif()
set(WITH_CUDA_BACKEND ${ACPP_DISCOVERED_CUDA_FOUND} CACHE BOOL "Build AdaptiveCpp support for NVIDIA GPUs with CUDA")
if(WITH_CUDA_BACKEND AND NOT ACPP_DISCOVERED_CUDA_FOUND)
  message(SEND_ERROR "WITH_CUDA_BACKEND is ON but no CUDA toolkit was found. Point CUDAToolkit_ROOT (or CUDA_TOOLKIT_ROOT_DIR) at it.")
endif()

if(WITH_CUDA_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/nvhpc.cmake)
else()
  set(ACPP_DISCOVERED_NVHPC_FOUND OFF)
endif()
if(WITH_CUDA_NVCXX_ONLY AND NOT ACPP_DISCOVERED_NVHPC_FOUND)
  message(SEND_ERROR "Could not find nvc++; specify it with -DNVCXX_COMPILER=")
endif()

if(NOT DEFINED WITH_ROCM_BACKEND OR WITH_ROCM_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/hip.cmake)
else()
  set(ACPP_DISCOVERED_HIP_FOUND OFF)
endif()
set(WITH_ROCM_BACKEND ${ACPP_DISCOVERED_HIP_FOUND} CACHE BOOL "Build AdaptiveCpp support for AMD GPUs with ROCm")
if(WITH_ROCM_BACKEND AND NOT ACPP_DISCOVERED_HIP_FOUND)
  message(SEND_ERROR "WITH_ROCM_BACKEND is ON but no ROCm/HIP installation was found. Point ROCM_PATH (or hip_ROOT) at it.")
endif()

if(WITH_OPENCL_BACKEND OR (NOT DEFINED WITH_OPENCL_BACKEND AND WITH_SSCP_COMPILER))
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/ocl.cmake)
else()
  set(ACPP_DISCOVERED_OCL_FOUND OFF)
endif()
set(WITH_OPENCL_BACKEND ${ACPP_DISCOVERED_OCL_FOUND} CACHE BOOL "Build AdaptiveCpp support for OpenCL SPIR-V devices supporting USM")
if(WITH_OPENCL_BACKEND AND NOT ACPP_DISCOVERED_OCL_FOUND)
  message(SEND_ERROR "WITH_OPENCL_BACKEND is ON but no OpenCL loader (2.1 or newer) was found. Point OpenCL_LIBRARY at it.")
endif()

if(WITH_LEVEL_ZERO_BACKEND OR (NOT DEFINED WITH_LEVEL_ZERO_BACKEND AND WITH_SSCP_COMPILER))
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/ze.cmake)
else()
  set(ACPP_DISCOVERED_ZE_FOUND OFF)
endif()
set(WITH_LEVEL_ZERO_BACKEND ${ACPP_DISCOVERED_ZE_FOUND} CACHE BOOL "Build AdaptiveCpp support for Intel GPUs with Level Zero")
if(WITH_LEVEL_ZERO_BACKEND AND NOT ACPP_DISCOVERED_ZE_FOUND)
  message(SEND_ERROR "WITH_LEVEL_ZERO_BACKEND is ON but no Level Zero loader (ze_loader) was found. Point ACPP_ZE_LOADER_LIBRARY at it.")
endif()

set(WITH_VULKAN_BACKEND OFF CACHE BOOL "Build AdaptiveCpp support for Vulkan") # OFF while experimental, as upstream
if(WITH_VULKAN_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/vk.cmake)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/clspv.cmake)
  if(NOT ACPP_DISCOVERED_VK_FOUND)
    message(SEND_ERROR "WITH_VULKAN_BACKEND is ON but the Vulkan loader, headers and SPIRV-Tools were not all found.")
  endif()
  if(NOT ACPP_DISCOVERED_CLSPV_FOUND)
    message(SEND_ERROR "WITH_VULKAN_BACKEND is ON but clspv was not found.")
  endif()
endif()

set(WITH_METAL_BACKEND OFF CACHE BOOL "Build AdaptiveCpp support for Apple GPUs with Metal (macOS only)")
if(WITH_METAL_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/metal.cmake)
  if(NOT ACPP_DISCOVERED_METAL_FOUND)
    message(SEND_ERROR "WITH_METAL_BACKEND is ON but the Metal framework was not found.")
  endif()
endif()

set(WITH_CPU_BACKEND true)


if(WITH_ACCELERATED_CPU) # sanitize input
  set(WITH_ACCELERATED_CPU true)
  set(BUILD_CLANG_PLUGIN true)
else()
  set(WITH_ACCELERATED_CPU false)
endif()

if(WITH_SSCP_COMPILER) # sanitize input
  set(WITH_SSCP_COMPILER true)
  set(BUILD_CLANG_PLUGIN true)
else()
  set(WITH_SSCP_COMPILER false)
endif()

if(WITH_STDPAR_COMPILER) # sanitize input
  set(WITH_STDPAR_COMPILER true)
  set(BUILD_CLANG_PLUGIN true)
else()
  set(WITH_STDPAR_COMPILER false)
endif()

if(WITH_CUDA_BACKEND)
  if(NOT WITH_CUDA_NVCXX_ONLY AND NOT ACPP_COMPILER_FEATURE_PROFILE STREQUAL "none")
    set(BUILD_CLANG_PLUGIN true)
  endif()
endif()
if(WITH_ROCM_BACKEND)
  set(BUILD_CLANG_PLUGIN true)
endif()
if(WITH_OPENCL_BACKEND OR WITH_LEVEL_ZERO_BACKEND)
  if(NOT ACPP_COMPILER_FEATURE_PROFILE STREQUAL "none" AND NOT ACPP_COMPILER_FEATURE_PROFILE STREQUAL "minimal")
    set(BUILD_CLANG_PLUGIN true)
    set(WITH_SSCP_COMPILER true)
  endif()
endif()

if(BUILD_CLANG_PLUGIN)
  if(NOT ACPP_LLVM_COMPONENT)
    set(LLVM_DIR_OLD ${LLVM_DIR})
    find_package(LLVM CONFIG)
    if(LLVM_DIR_OLD AND NOT ("${LLVM_DIR_OLD}" STREQUAL "${LLVM_DIR}"))
      message(WARNING "Could not find LLVM in the requested location LLVM_DIR=${LLVM_DIR_OLD}; using ${LLVM_DIR}.")
    endif()
    message(STATUS "Building AdaptiveCpp against LLVM configured from ${LLVM_DIR}")
    
    find_path(CLANG_AST_HEADER_DIR
      NAMES clang/AST/ASTContext.h
      PATHS ${LLVM_INCLUDE_DIRS}
      DOC "Path to the Clang AST headers (usually provided by libclang-dev)"
    )
    if(NOT CLANG_AST_HEADER_DIR)
      message(WARNING 
        "AdaptiveCpp requires clang development headers, but they were not found.\n"
        "You might need to install the clang development package (e.g. libclang-dev or similar).\n"
      )
    endif()

    find_program(CLANG_EXECUTABLE_PATH NAMES clang++-${LLVM_VERSION_MAJOR} clang++-${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR} clang++ HINTS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH CACHE STRING)
    if(CLANG_EXECUTABLE_PATH MATCHES "-NOTFOUND")
      find_program(CLANG_EXECUTABLE_PATH NAMES clang++-${LLVM_VERSION_MAJOR} clang++-${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR} clang++ CACHE STRING)
      if(CLANG_EXECUTABLE_PATH MATCHES "-NOTFOUND")
        message(SEND_ERROR "Could not find clang executable")
      endif()
    endif()
    if(WIN32)
      # plugins link agains clang.exe and not clang++.exe, thus using clang++ would result
      # in symbol clashes and therefore the plugin not loading.
      # on Windows it seems to be fine, as long as clang is able to deduce the language
      # from the file extension, as the msvcrt is linked explicitly anyways.
      string(REPLACE "clang++.exe" "clang.exe" CLANG_EXECUTABLE_PATH ${CLANG_EXECUTABLE_PATH})
    endif()
    message(STATUS "Selecting clang: ${CLANG_EXECUTABLE_PATH}")

    get_filename_component(LLVM_BIN_DIR "${CLANG_EXECUTABLE_PATH}" DIRECTORY)
    get_filename_component(LLVM_PREFIX_DIR "${LLVM_BIN_DIR}" DIRECTORY)
    # The path to the internal clang includes is currently required on ROCm
    # to let acpp fix a wrong order of system includes (clang's internal
    # includes are not of high enough priority in the include path search order).
    # We identify this path as the one containing __clang_cuda_runtime_wrapper.h,
    # which is a clang-specific header file.
    find_path(FOUND_CLANG_INCLUDE_PATH __clang_cuda_runtime_wrapper.h HINTS
      ${LLVM_PREFIX_DIR}/include/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}.${LLVM_VERSION_PATCH}/include
      ${LLVM_PREFIX_DIR}/include/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}/include
      ${LLVM_PREFIX_DIR}/include/clang/${LLVM_VERSION_MAJOR}/include
      ${LLVM_PREFIX_DIR}/lib/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}.${LLVM_VERSION_PATCH}/include
      ${LLVM_PREFIX_DIR}/lib/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}/include
      ${LLVM_PREFIX_DIR}/lib/clang/${LLVM_VERSION_MAJOR}/include
      ${LLVM_PREFIX_DIR}/lib64/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}.${LLVM_VERSION_PATCH}/include
      ${LLVM_PREFIX_DIR}/lib64/clang/${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}/include
      ${LLVM_PREFIX_DIR}/lib64/clang/${LLVM_VERSION_MAJOR}/include
      DOC "Path to internal clang headers. Typically, $LLVM_INSTALL_PREFIX/include/clang/<llvm-version>/include")

    if(EXISTS ${FOUND_CLANG_INCLUDE_PATH})
      # Required for newer ROCm versions
      set(CLANG_INCLUDE_PATH ${FOUND_CLANG_INCLUDE_PATH}/..)
    endif()
  
    if(NOT EXISTS ${CLANG_INCLUDE_PATH})
      message(SEND_ERROR "CLANG_INCLUDE_PATH ${CLANG_INCLUDE_PATH} does not exist. Please provide clang's internal include path manually: Find the directory where __clang_cuda_runtime_wrapper.h is. Provide this directory for older ROCm versions and the parent directory for newer ones.")
    endif()
    if(WITH_ROCM_BACKEND)
      # Check if we're building against ROCm LLVM. This code checks if
      # CLANG_EXECUTABLE_PATH is located within the discovered ROCm prefix.
      # Note: This might fail in ROCm distributions where ROCm is strongly decomposed
      # (spack?) but it is more reliable than just parsing the output of clang++ --version.
      # This is then later used to decide whether we need to make exemptions
      # from LLVM version compatibility checks.
      file(GLOB_RECURSE ROCM_FOUND_FILES FOLLOW_SYMLINKS "${ACPP_DISCOVERED_HIP_PREFIX}/bin/*" "${ACPP_DISCOVERED_HIP_PREFIX}/llvm/bin/*" "${ACPP_DISCOVERED_HIP_PREFIX}/lib/llvm/bin/*")
      if ("${CLANG_EXECUTABLE_PATH}" IN_LIST ROCM_FOUND_FILES)
        message(STATUS "${CLANG_EXECUTABLE_PATH} found in ${ACPP_DISCOVERED_HIP_PREFIX}; assuming that we are building against ROCm LLVM")
        set(USE_ROCM_LLVM true)
      else()
        set(USE_ROCM_LLVM false)
      endif()

      find_program(ROCM_CLANG_PATH NAMES clang++ HINTS ${ACPP_DISCOVERED_HIP_PREFIX} ${ACPP_DISCOVERED_HIP_PREFIX}/bin ${ACPP_DISCOVERED_HIP_PREFIX}/llvm/bin NO_DEFAULT_PATH CACHE STRING)
      if(ROCM_CLANG_PATH)
        # Figure out ROCm LLVM version - this is used to check whether the AdaptiveCpp LLVM version
        # is compatible with ROCm for SSCP.
        # Note: We have an extra code path here in addition to the one below to find out
        # the ROCm version for robustness, since some ROCm distributions identify differently!
        message(STATUS "Found ROCm clang: ${ROCM_CLANG_PATH}")
        execute_process(COMMAND ${ROCM_CLANG_PATH} "--version"
          OUTPUT_VARIABLE ROCM_CLANG_VERBOSE_OUTPUT)
        string(REGEX MATCH "clang version ([0-9]+)\\.([0-9]+)\\.([0-9]+)" ROCM_CLANG_VERSION ${ROCM_CLANG_VERBOSE_OUTPUT})
        if(ROCM_CLANG_VERSION)
          set(ROCM_LLVM_MAJOR ${CMAKE_MATCH_1})
          set(ROCM_LLVM_MINOR ${CMAKE_MATCH_2})
          set(ROCM_LLVM_PATCH ${CMAKE_MATCH_3})
          message(STATUS "ROCm LLVM version: ${ROCM_LLVM_MAJOR}.${ROCM_LLVM_MINOR}.${ROCM_LLVM_PATCH}")
          # If we want to target ROCm with SSCP, then AdaptiveCpp LLVM must be <= ROCm LLVM
          if(ROCM_LLVM_MAJOR AND LLVM_VERSION_MAJOR AND WITH_SSCP_COMPILER)
            if(${LLVM_VERSION_MAJOR} GREATER ${ROCM_LLVM_MAJOR})
              if(NOT ACPP_EXPERIMENTAL_LLVM)
                message(SEND_ERROR "AdaptiveCpp LLVM version (${LLVM_VERSION_MAJOR}) must be <= ROCm LLVM version (${ROCM_LLVM_MAJOR}) for the AdaptiveCpp generic JIT compiler. Use -DACPP_EXPERIMENTAL_LLVM=ON if you still want to try your luck.")
              else()
                message(WARNING "Building AdaptiveCpp with LLVM/ROCm version combination that is known to break the generic JIT compiler (--acpp-targets=generic)")
              endif()
            endif()
          endif()
        endif()
      endif()
      # Find ROCm version - this may not work for ROCm distributions repackaged
      # by Linux distributions as they may be missing the roc-* identifier in the output :(
      execute_process(COMMAND ${CLANG_EXECUTABLE_PATH} "--version"
        OUTPUT_VARIABLE CLANG_VERBOSE_OUTPUT)
      string(REGEX MATCH "clang version [0-9]+\\.[0-9]+\\.[0-9]+[a-zA-Z]* \\(.+ roc-([0-9]+)\\.([0-9]+)\\.([0-9]+)" AMD_CLANG_VERSION ${CLANG_VERBOSE_OUTPUT})

      if(AMD_CLANG_VERSION)
        set(ROCM_VERSION_MAJOR ${CMAKE_MATCH_1})
        set(ROCM_VERSION_MINOR ${CMAKE_MATCH_2})
        set(ROCM_VERSION_PATCH ${CMAKE_MATCH_3})
        message(STATUS "AMD clang version: ${ROCM_VERSION_MAJOR}.${ROCM_VERSION_MINOR}.${ROCM_VERSION_PATCH}")
      endif()
    endif()
    
  else() # Build as LLVM Component
    # Add path for custom modules
    list(INSERT CMAKE_MODULE_PATH 0
      "${LLVM_MAIN_SRC_DIR}/../cmake/Modules"
      )

    set(CLANG_EXECUTABLE_PATH $<TARGET_FILE:clang>)

    include(GetClangResourceDir)
    get_clang_resource_dir(CLANG_INCLUDE_PATH SUBDIR include)

    if(CLANG_VENDOR STREQUAL "AMD")
      message(WARNING "Building AdaptiveCpp as part of AMD Clang, ROCm version not known, can't apply specific workarounds.")
    elseif(${CMAKE_PROJECT_VERSION_MINOR} EQUAL 0)
      message(WARNING "Building AdaptiveCpp with an unreleased LLVM version, expect incompatibilities.")
    endif()
  endif()

  if(${LLVM_VERSION_MAJOR} LESS 15)
    if(${WITH_ACCELERATED_CPU} OR ${WITH_SSCP_COMPILER} OR ${WITH_STDPAR_COMPILER})
      message(WARNING "clang version too old (${LLVM_VERSION_MAJOR} < 15) to be used with advanced AdaptiveCpp compiler features, disabling WITH_STDPAR_COMPILER, WITH_ACCELERATED_CPU, WITH_SSCP_COMPILER")
      set(WITH_STDPAR_COMPILER false)
      set(WITH_SSCP_COMPILER false)
      set(WITH_ACCELERATED_CPU false)
    endif()
  endif()

  set(ENFORCE_COMPATIBLE_LLVM true)
  if(USE_ROCM_LLVM)
    if(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "minimal")
      set(ENFORCE_COMPATIBLE_LLVM false)
    endif()
    if(NOT ${WITH_SSCP_COMPILER} AND NOT ${WITH_STDPAR_COMPILER} AND NOT ${WITH_ACCELERATED_CPU})
      set(ENFORCE_COMPATIBLE_LLVM false)
    endif()
  endif()
  if(ENFORCE_COMPATIBLE_LLVM AND NOT ACPP_EXPERIMENTAL_LLVM)
    if(${LLVM_VERSION_MAJOR} GREATER 21)
      message(SEND_ERROR "LLVM versions greater than 21 are not yet tested/supported, use -DACPP_EXPERIMENTAL_LLVM=ON if you still wish to try your luck.")
    endif()
    if(${LLVM_VERSION_MAJOR} GREATER 17)
      # Starting from LLVM 18, releases will have LLVM_VERSION_MINOR>0
      if(${LLVM_VERSION_MINOR} EQUAL 0)
        message(SEND_ERROR "This LLVM seems to be a development version; only LLVM releases are tested and supported. Use -DACPP_EXPERIMENTAL_LLVM=ON if you still wish to try your luck.")
      endif()
    endif()
  endif()

  message(STATUS "Using clang include directory: ${CLANG_INCLUDE_PATH}")

  # Check if building on Windows and LLVM_LIBS is set, if not, use LLVM_AVAILABLE_LIBS 
  if(WIN32 AND NOT LLVM_LIBS AND LLVM_AVAILABLE_LIBS)
    llvm_map_components_to_libnames(LLVM_LIBS analysis core support passes)
  endif()
endif()

#add_compile_definitions(HIPSYCL_DEBUG_LEVEL="${HIPSYCL_DEBUG_LEVEL}")
#Use add_definitions for now for older cmake versions
cmake_policy(SET CMP0005 NEW)
add_definitions(-DHIPSYCL_DEBUG_LEVEL=${HIPSYCL_DEBUG_LEVEL})

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# The install prefix is deliberately not recorded in the binaries. The only
# mechanism for finding the installation is asking the dynamic loader where
# our own libraries are (get_lib_directory()); a compiled-in fallback would
# name the machine that built the toolchain, and both readers treat the value
# as a fallback behind that lookup.
set(ACPP_RECORDED_INSTALL_PREFIX "")

set(ACPP_CONFIG_FILE_INSTALL_DIR etc/AdaptiveCpp)

if(APPLE)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(DEFAULT_OMP_FLAG "-Xclang -fopenmp")
  else()
    set(DEFAULT_OMP_FLAG "-fopenmp")
  endif()
else()
  set(DEFAULT_OMP_FLAG "-fopenmp")
endif()


set(ACPP_FILESYSTEM_SEARCH_OPTIONS "Final;Experimental;Boost" CACHE STRING "Which filesystem libraries should be searched for")

# Vector math library discovery. The add_definitions that turn these results
# into compile definitions remain in src/compiler and read the variables set
# here. The selection order is load-bearing: libmvec is the default when
# usable, and the
# architecture-specific libraries override it.
if(APPLE OR WIN32)
  message(WARNING "Usage of vector math library for JIT compilation is not supported on windows and Apple")
  set(DEFAULT_VEC_MATH_LIB none)
else()

  #LIBMVEC
  find_library(LIBMVEC NAMES mvec)

  if(LIBMVEC)
    #Check that libmvec is recent enough
    include(CheckFunctionExists)
    set(CMAKE_REQUIRED_LIBRARIES "${LIBMVEC}")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
      check_function_exists("_ZGVnN2v_atanhf" LIBMVEC_HAS_REQUIRED_SYMBOLS)
    else()
      check_function_exists("_ZGVdN8v_tanf" LIBMVEC_HAS_REQUIRED_SYMBOLS)
    endif()
    unset(CMAKE_REQUIRED_LIBRARIES)

    #Check clang support libmvec
    set(CLANG_SUPPORT_LIBMVEC true)
    if(${LLVM_VERSION_MAJOR} LESS 21)
      #Only clang 21+ support libmvec on aarch64
      if(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
        set(CLANG_SUPPORT_LIBMVEC false)
      endif()
    endif()
  endif()

  if(LIBMVEC AND LIBMVEC_HAS_REQUIRED_SYMBOLS AND CLANG_SUPPORT_LIBMVEC)
    # find_library's answer is used to DETECT libmvec here and nowhere else.
    # Its path is deliberately not compiled in: libmvec is part of glibc, so
    # the only correct copy is the one the dynamic loader resolves in the
    # process that is JIT-compiling, which is the user's application and not
    # this build. getLibMvecDir() asks the loader for it at run time.
    set(DEFAULT_VEC_MATH_LIB libmvec)

    message( STATUS "LIBMVEC found at ${LIBMVEC}")
  elseif(NOT LIBMVEC)
    message(STATUS "LIBMVEC was not found")
  elseif(NOT LIBMVEC_HAS_REQUIRED_SYMBOLS)
    message(STATUS "LIBMVEC found at ${LIBMVEC}, but does not provide required functions (likely too old)")
  elseif(NOT CLANG_SUPPORT_LIBMVEC)
    message(STATUS "LIBMVEC was found at ${LIBMVEC}, but the detected LLVM version (${LLVM_VERSION_MAJOR}) does not support LIBMVEC.")
  endif()

  #SLEEF
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
    find_library(LIBSLEEF NAMES sleefgnuabi)

    if(LIBSLEEF)
      set(DEFAULT_VEC_MATH_LIB sleef)

      message( STATUS "SLEEF found at ${LIBSLEEF}")
    else()
      message( STATUS "SLEEF was not found")
    endif()
  else()
    message( STATUS "SLEEF not available on X86")
  endif()

  #AMATH
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
    find_library(LIBAMATH NAMES amath)

    if(LIBAMATH)
      set(DEFAULT_VEC_MATH_LIB armpl)

      message( STATUS "AMATH found at ${LIBAMATH}")
    else()
      message( STATUS "AMATH was not found")
    endif()
  else()
    message( STATUS "AMATH not available on X86")
  endif()

  #SVML
  if(NOT CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
    find_library(LIBSVML NAMES svml)
    find_library(LIBINTLC NAMES intlc)

    if(LIBSVML AND LIBINTLC )
      set(DEFAULT_VEC_MATH_LIB svml)

      message( STATUS "SVML found at ${LIBSVML} (INTLC found at ${LIBINTLC})")
    else()
      message( STATUS "SVML was not found")
    endif()
  else()
    message( STATUS "SVML not available on AArch64")
  endif()
endif()

##########################################################
## Discovery, options and the installed-config units.
##
## Runs after every WITH_*_BACKEND has been decided (immediately above)
## and after include(GNUInstallDirs) (near the top of this file), but
## before add_subdirectory(src): src/CMakeLists.txt reads the
## ACPP_<VENDOR>_SHIPPED gate the corresponding options file's
## acpp_declare_vendor() call sets, below.
##
## Backend discovery already ran above, where each WITH_*_BACKEND took its
## default from it; the per-unit includes below re-include those files as
## no-ops (include_guard) purely so each options file visibly follows its
## own discovery.
##
## Separately, cmake/discovery.cmake's own LLVM half (not a vendor file)
## requires LLVM whenever ACPP_COMPILER_FEATURE_PROFILE is not "none",
## which is slightly wider than this file's own BUILD_CLANG_PLUGIN gate
## (a "minimal" profile with every WITH_*_BACKEND off never sets
## BUILD_CLANG_PLUGIN, so never finds LLVM today) - consistent with the
## new model, where the device compiler is unconditionally either ours
## or the machine's, never absent, but a real behaviour widening for that
## one narrow combination. Left as is: there is no LLVM in this sandbox
## to test either behaviour against, and reconciling BUILD_CLANG_PLUGIN's
## ad-hoc gate with the options model's own ownership rules is later
## wiring, not this step's.
##########################################################

include(${ACPP_SOURCE_ROOT}/cmake/discovery.cmake)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(ACPP_OPTIONS_PLATFORM "linux")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(ACPP_OPTIONS_PLATFORM "macos")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(ACPP_OPTIONS_PLATFORM "windows")
else()
  message(FATAL_ERROR
    "AdaptiveCpp's options model has no directory for "
    "CMAKE_SYSTEM_NAME='${CMAKE_SYSTEM_NAME}'; supported platforms are "
    "Linux, Darwin and Windows.")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  set(ACPP_OPTIONS_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|ARM64|arm64)$")
  set(ACPP_OPTIONS_ARCH "aarch64")
else()
  message(FATAL_ERROR
    "AdaptiveCpp's options model has no directory for "
    "CMAKE_SYSTEM_PROCESSOR='${CMAKE_SYSTEM_PROCESSOR}' on "
    "${ACPP_OPTIONS_PLATFORM}; supported architectures are x86_64 and "
    "aarch64 (arm64 on macOS).")
endif()

# macOS's options directory is named arm64 (Apple's own spelling), not
# aarch64 - the only platform where the two names differ.
if(ACPP_OPTIONS_PLATFORM STREQUAL "macos")
  set(ACPP_OPTIONS_ARCH "arm64")
endif()

set(ACPP_OPTIONS_DIR "${ACPP_SOURCE_ROOT}/cmake/options/${ACPP_OPTIONS_PLATFORM}/${ACPP_OPTIONS_ARCH}")
if(NOT EXISTS "${ACPP_OPTIONS_DIR}/core.cmake")
  message(FATAL_ERROR
    "No options directory for ${ACPP_OPTIONS_PLATFORM}/${ACPP_OPTIONS_ARCH} "
    "(looked for ${ACPP_OPTIONS_DIR}/core.cmake).")
endif()

include(${ACPP_OPTIONS_DIR}/core.cmake)

# The units the installed configs (etc/AdaptiveCpp/acpp-*) merge, one per
# enabled vendor - core and omp are acpp_generate_installed_configs' own
# unconditional additions (cmake/acpp-installed-configs.cmake), so they
# are not listed here. Each vendor's own discovery file runs immediately
# before its options file, which is what reads ACPP_DISCOVERED_<VENDOR>_*
# to declare the vendor unit (acpp_declare_vendor/acpp_declare_vendor_root
# in cmake/options/common/core.cmake).
set(ACPP_UNITS "")

if(WITH_CUDA_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/cuda.cmake)
  include(${ACPP_OPTIONS_DIR}/cuda.cmake)
  list(APPEND ACPP_UNITS cuda)

  # nvhpc is CUDA's nvc++-based alternative flow, Linux-only; its own
  # options file only exists there. Gated on discovery actually finding
  # nvc++ (ACPP_DISCOVERED_NVHPC_FOUND), not merely on WITH_CUDA_BACKEND -
  # unlike cuda itself, there is no "unit exists but not shipped" shape
  # for a compiler binary that flatly is not on this machine.
  if(EXISTS "${ACPP_OPTIONS_DIR}/nvhpc.cmake")
    include(${ACPP_SOURCE_ROOT}/cmake/discovery/nvhpc.cmake)
    if(ACPP_DISCOVERED_NVHPC_FOUND)
      include(${ACPP_OPTIONS_DIR}/nvhpc.cmake)
      list(APPEND ACPP_UNITS nvhpc)
    endif()
  endif()
endif()

if(WITH_ROCM_BACKEND AND EXISTS "${ACPP_OPTIONS_DIR}/hip.cmake")
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/hip.cmake)
  include(${ACPP_OPTIONS_DIR}/hip.cmake)
  list(APPEND ACPP_UNITS hip)
endif()

if(WITH_OPENCL_BACKEND AND EXISTS "${ACPP_OPTIONS_DIR}/ocl.cmake")
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/ocl.cmake)
  include(${ACPP_OPTIONS_DIR}/ocl.cmake)
  list(APPEND ACPP_UNITS ocl)
endif()

if(WITH_LEVEL_ZERO_BACKEND AND EXISTS "${ACPP_OPTIONS_DIR}/ze.cmake")
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/ze.cmake)
  include(${ACPP_OPTIONS_DIR}/ze.cmake)
  list(APPEND ACPP_UNITS ze)
endif()

if(WITH_VULKAN_BACKEND)
  include(${ACPP_SOURCE_ROOT}/cmake/discovery/vk.cmake)
  include(${ACPP_OPTIONS_DIR}/vk.cmake)
  list(APPEND ACPP_UNITS vk)

  include(${ACPP_SOURCE_ROOT}/cmake/discovery/clspv.cmake)
  include(${ACPP_OPTIONS_DIR}/clspv.cmake)
  list(APPEND ACPP_UNITS clspv)
endif()

# Metal is macOS's own backend: no options file (no vendor knobs - the
# runtime compiles MSL through the system Metal framework at run time, so
# there is nothing to ship), only a deploy manifest fragment
# (config/macos/common/deploy/metal.json) for the libraries WE build.
# WITH_METAL_BACKEND is read (src/CMakeLists.txt, src/runtime/CMakeLists.
# txt) but, like WITH_LEVEL_ZERO_BACKEND, not yet given a discovery-based
# default here - a later step's job, not this one's.
if(WITH_METAL_BACKEND)
  list(APPEND ACPP_UNITS metal)
endif()

# acpp_add_vendor_rpaths (cmake/acpp-vendor-rpath.cmake) must be defined
# before add_subdirectory(src): src/runtime/CMakeLists.txt and
# src/compiler/llvm-to-backend/CMakeLists.txt call it on their own backend
# targets as those targets are created, not afterward. Every
# ACPP_<STEM>_SHIPPED/ACPP_<STEM>_SUBDIR it reads is already set, from the
# options includes immediately above. This also pulls in
# cmake/acpp-vendor-install.cmake (for its small path-join helper) - a
# second include() of that file below, after add_subdirectory(src) for the
# per-unit install rules themselves, is a no-op under its own
# include_guard(GLOBAL).
include(${ACPP_SOURCE_ROOT}/cmake/acpp-vendor-rpath.cmake)

##########################################################
## Do not define any variables that might be used by build
## targets below this line.
##########################################################
add_subdirectory(src)

set(DEFAULT_WIN32_CUDA_LINK_LINE "-L$ACPP_CUDA_LIB_PATH -lcudart")
set(DEFAULT_CUDA_LINK_LINE "-Wl,-rpath=$ACPP_CUDA_LIB_PATH -L$ACPP_CUDA_LIB_PATH -lcudart")

set(DEFAULT_WIN32_HIP_LINK_LINE "-L$ACPP_ROCM_PATH/lib -lamdhip64")

if(MINGW)
  set(DEFAULT_LINK_PREFIX "-l:")
else()
  set(DEFAULT_LINK_PREFIX "-l")
endif()

set(DEFAULT_WIN32_OMP_LINK_LINE "${DEFAULT_OMP_FLAG}")
set(DEFAULT_WIN32_SEQUENTIAL_LINK_LINE "-llibomp")

# need add_subdirectory(src) before this!
set(DEFAULT_APPLE_OMP_LINK_LINE "${DEFAULT_OMP_FLAG} ${hipSYCL_OpenMP_CXX_LIBRARIES}")
set(DEFAULT_APPLE_SEQUENTIAL_LINK_LINE "${hipSYCL_OpenMP_CXX_LIBRARIES}")
set(DEFAULT_OMP_LINK_LINE "${DEFAULT_OMP_FLAG}")
set(DEFAULT_SEQUENTIAL_LINK_LINE "")

# If no link lines given, set to default.
if(WIN32)
  if(NOT ROCM_LINK_LINE)
    set(ROCM_LINK_LINE ${DEFAULT_WIN32_HIP_LINK_LINE} CACHE STRING "Arguments passed to compiler to link ROCm libraries to SYCL applications")
  endif()
else()
  if(NOT ROCM_LINK_LINE)
    set(ROCM_LINK_LINE "-Wl,-rpath=$ACPP_ROCM_PATH/lib -Wl,-rpath=$ACPP_ROCM_PATH/hip/lib ${ROCM_LIBS}" CACHE STRING "Arguments passed to compiler to link ROCm libraries to SYCL applications")
  endif()
endif()

if(WIN32)
  if(NOT CUDA_LINK_LINE)
    set(CUDA_LINK_LINE ${DEFAULT_WIN32_CUDA_LINK_LINE} CACHE STRING "Arguments passed to compiler to link CUDA libraries to SYCL applications")
  endif()
  if(NOT OMP_LINK_LINE)
    set(OMP_LINK_LINE ${DEFAULT_WIN32_OMP_LINK_LINE} CACHE STRING "Arguments passed to compiler to link OpenMP libraries to SYCL applications")
  endif()
  if(NOT SEQUENTIAL_LINK_LINE)
    set(SEQUENTIAL_LINK_LINE ${DEFAULT_WIN32_SEQUENTIAL_LINK_LINE} CACHE STRING "Arguments passed to compiler to link host libraries to SYCL applications")
  endif()
elseif(APPLE)
  if(NOT CUDA_LINK_LINE) # no CUDA support here.. but make CMake happy.
    set(CUDA_LINK_LINE "" CACHE STRING "Arguments passed to compiler to link CUDA libraries to SYCL applications")
  endif()
  if(NOT OMP_LINK_LINE)
    set(OMP_LINK_LINE ${DEFAULT_APPLE_OMP_LINK_LINE} CACHE STRING "Arguments passed to compiler to link OpenMP libraries to SYCL applications")
  endif()
  if(NOT SEQUENTIAL_LINK_LINE)
    set(SEQUENTIAL_LINK_LINE ${DEFAULT_APPLE_SEQUENTIAL_LINK_LINE} CACHE STRING "Arguments passed to compiler to link host libraries to SYCL applications")
  endif()
else()
  if(NOT CUDA_LINK_LINE)
    set(CUDA_LINK_LINE ${DEFAULT_CUDA_LINK_LINE} CACHE STRING "Arguments passed to compiler to link CUDA libraries to SYCL applications")
  endif()
  if(NOT OMP_LINK_LINE)
    set(OMP_LINK_LINE ${DEFAULT_OMP_LINK_LINE} CACHE STRING "Arguments passed to compiler to link OpenMP libraries to SYCL applications")
  endif()
  if(NOT SEQUENTIAL_LINK_LINE)
    set(SEQUENTIAL_LINK_LINE ${DEFAULT_SEQUENTIAL_LINK_LINE} CACHE STRING "Arguments passed to compiler to link host libraries to SYCL applications")
  endif()
endif()

# ROCM_CXX_FLAGS/CUDA_CXX_FLAGS (both $ACPP_PATH-based) used to default
# here; nothing reads either cache variable any more - the options model's
# own ACPP_HIP_CXX_FLAGS/ACPP_CUDA_CXX_FLAGS (cmake/options/*/common/
# {hip,cuda}.cmake, {{ }}-templated, never a baked absolute path) already
# supersede both, and are what config/*/hip.json's/cuda.json's
# "hip-cxx-flags"/"cuda-cxx-flags" entries actually read.

# always need -D_ENABLE_EXTENDED_ALIGNED_STORAGE to allow correctly aligned local memory on CPU
if(NOT OMP_CXX_FLAGS)
  set(OMP_CXX_FLAGS "${DEFAULT_OMP_FLAG} -D_ENABLE_EXTENDED_ALIGNED_STORAGE" CACHE STRING "Arguments passed to compiler to compile SYCL applications with OpenMP")
endif()

if(NOT SEQUENTIAL_CXX_FLAGS)
  set(SEQUENTIAL_CXX_FLAGS "-D_ENABLE_EXTENDED_ALIGNED_STORAGE" CACHE STRING "Arguments passed to compiler to compile SYCL applications on host")
endif()

if(BUILD_CLANG_PLUGIN)
  set(PLUGIN_LLVM_VERSION_MAJOR ${LLVM_VERSION_MAJOR})
else()
  set(PLUGIN_LLVM_VERSION_MAJOR 0)
endif()

set(DEFAULT_GPU_ARCH "" CACHE STRING "(Deprecated, use DEFAULT_TARGETS instead) Optional: Default GPU architecture to compile for when targeting GPUs (e.g.: sm_60 or gfx900)")
set(DEFAULT_TARGETS "" CACHE STRING "Default targets to compile for")

if(NOT DEFAULT_TARGETS)
  if(DEFAULT_PLATFORM)
    message(DEPRECATION "DEFAULT_PLATFORM is deprecated; use DEFAULT_TARGETS instead.")

    if(DEFAULT_PLATFORM STREQUAL "cpu")
      set(DEFAULT_TARGETS "omp")
    endif()

    if(DEFAULT_GPU_ARCH)
      message(DEPRECATION "DEFAULT_GPU_ARCH is deprecated; use DEFAULT_TARGETS instead.")

      if(DEFAULT_PLATFORM STREQUAL "cuda")
        set(DEFAULT_TARGETS "cuda:${DEFAULT_GPU_ARCH}")
      elseif(DEFAULT_PLATFORM STREQUAL "rocm")
        set(DEFAULT_TARGETS "hip:${DEFAULT_GPU_ARCH}")
      else()
        message(SEND_ERROR "Invalid value for DEFAULT_PLATFORM: \"${DEFAULT_PLATFORM}\". When DEFAULT_GPU_ARCH is specified, only \"cuda\" and \"rocm\" are supported.")
      endif()

    endif()
  elseif(DEFAULT_GPU_ARCH)
    message(DEPRECATION "DEFAULT_GPU_ARCH is deprecated; use DEFAULT_TARGETS instead.")
    message(SEND_ERROR "DEFAULT_GPU_ARCH cannot be used without specifying DEFAULT_PLATFORM.")
  endif()
endif()

if(NOT DEFAULT_TARGETS)
  if(WITH_SSCP_COMPILER)
    set(DEFAULT_TARGETS "generic")
  else()
    message(WARNING "The generic SSCP compiler is disabled; without it, offloading code to accelerators requires explicitly specifying --acpp-targets when invoking acpp."
" A binary generated by invoking acpp without --acpp-targets will only be able to run on the host. Set -DDEFAULT_TARGETS to your desired default targets during cmake "
" configuration to avoid this warning. In the future, configurations without the SSCP compiler enabled might potentially be only supported if -DDEFAULT_TARGETS is provided explicitly.")
    set(DEFAULT_TARGETS "omp")
  endif()
endif()

message(STATUS "Default compilation target(s): ${DEFAULT_TARGETS}")

##########################################################
## Generate the installed toolchain config, deploy manifest and app
## config, then the per-vendor install rules. After add_subdirectory(src)
## so every variable it declares exists, and after DEFAULT_TARGETS is
## finally computed (immediately above) so the fix below has something to
## read - nothing else acpp_generate_installed_configs reads comes from
## further down this file (the legacy OMP_LINK_LINE/CUDA_CXX_FLAGS-style
## variables computed nearby are a different, non-ACPP_-prefixed namespace
## the options model does not read).
##
## cmake/options/common/core.cmake defaults ACPP_TARGETS from
## ${DEFAULT_TARGETS} with a guarded plain set() the moment the options
## file is included (well above, before add_subdirectory(src)), when
## DEFAULT_TARGETS was still empty - the options model runs before this
## file's own legacy DEFAULT_TARGETS logic does. Since that set() was
## plain, not CACHE, it can simply be corrected now that DEFAULT_TARGETS
## has its real answer, the same way every other guarded default in this
## file works: only if a builder has not already overridden ACPP_TARGETS
## themselves (which the options model's own guard already protects).
##########################################################
if("${ACPP_TARGETS}" STREQUAL "" AND NOT "${DEFAULT_TARGETS}" STREQUAL "")
  set(ACPP_TARGETS "${DEFAULT_TARGETS}")
endif()

include(${ACPP_SOURCE_ROOT}/cmake/acpp-installed-configs.cmake)

acpp_generate_installed_configs(
  PLATFORM "${ACPP_OPTIONS_PLATFORM}"
  ARCH "${ACPP_OPTIONS_ARCH}"
  UNITS ${ACPP_UNITS}
  OUT_DIR "${ACPP_BINARY_ROOT}/etc/AdaptiveCpp")

install(FILES "${ACPP_BINARY_ROOT}/etc/AdaptiveCpp/acpp-toolchain.json"
  DESTINATION ${ACPP_CONFIG_FILE_INSTALL_DIR})
install(FILES "${ACPP_BINARY_ROOT}/etc/AdaptiveCpp/acpp-app.cfg"
  DESTINATION ${ACPP_CONFIG_FILE_INSTALL_DIR})
if(NOT ACPP_DEPLOYMENT_STRATEGY STREQUAL "managed")
  install(FILES "${ACPP_BINARY_ROOT}/etc/AdaptiveCpp/acpp-deploy.json"
    DESTINATION ${ACPP_CONFIG_FILE_INSTALL_DIR})
endif()

# Per-vendor cmake install rules: home (a)+(b) of the three-part manifest
# (doc/configuration-model.md, "The manifest") - what physically ships
# alongside the toolchain under the full strategies, both the
# toolchain-only pieces (headers, ptxas-class tools, import libraries) and
# everything the manifest above also deploys with an application. Every
# call inside cmake/install/<platform>/common/<unit>.cmake is a no-op
# unless that unit is ACPP_<STEM>_SHIPPED (cmake/acpp-vendor-install.cmake).
# omp is not in ACPP_UNITS (core and omp are acpp_generate_installed_configs'
# own unconditional additions, not units this file tracks - see the
# ACPP_UNITS comment above, near cmake/discovery.cmake's own include), so
# it needs a call of its own, unconditional on the loop below, matching
# that same reasoning. "when it exists" (per the design walkthrough): not
# every unit has an install file yet, and not every platform ships every
# unit (no cuda.cmake under cmake/install/macos, for instance) - EXISTS
# guards both.
include(${ACPP_SOURCE_ROOT}/cmake/acpp-vendor-install.cmake)

foreach(_acpp_unit IN LISTS ACPP_UNITS)
  set(_acpp_install_file "${ACPP_SOURCE_ROOT}/cmake/install/${ACPP_OPTIONS_PLATFORM}/common/${_acpp_unit}.cmake")
  if(EXISTS "${_acpp_install_file}")
    include(${_acpp_install_file})
  endif()
endforeach()

set(_acpp_omp_install_file "${ACPP_SOURCE_ROOT}/cmake/install/${ACPP_OPTIONS_PLATFORM}/common/omp.cmake")
if(EXISTS "${_acpp_omp_install_file}")
  include(${_acpp_omp_install_file})
endif()

# Core's own external vendor units (sleef, amath, libnuma, svml/intlc) are
# not behind any WITH_*_BACKEND flag - see cmake/install/linux/common/
# core.cmake's own header - so, like omp above, they need a call of their
# own rather than a place in the ACPP_UNITS loop. Both the common tier and
# the one arch that has its own (svml/intlc, linux/x86_64 only) are
# EXISTS-guarded the same way.
set(_acpp_core_common_install_file "${ACPP_SOURCE_ROOT}/cmake/install/${ACPP_OPTIONS_PLATFORM}/common/core.cmake")
if(EXISTS "${_acpp_core_common_install_file}")
  include(${_acpp_core_common_install_file})
endif()

set(_acpp_core_arch_install_file "${ACPP_SOURCE_ROOT}/cmake/install/${ACPP_OPTIONS_PLATFORM}/${ACPP_OPTIONS_ARCH}/core.cmake")
if(EXISTS "${_acpp_core_arch_install_file}")
  include(${_acpp_core_arch_install_file})
endif()




# must stay after add_subdirectory(src) as HIPSYCL_COMMON_LIBRARY_OUTPUT_NAME is declared there
configure_file(
  ${ACPP_SOURCE_ROOT}/include/hipSYCL/common/config.hpp.in
  ${ACPP_BINARY_ROOT}/include/hipSYCL/common/config.hpp
  )

set(ACPP_PCUDA_PREFIX "cuda")
set(ACPP_PCUDA_CAPITAL_PREFIX "CUDA")
configure_file(
  ${ACPP_SOURCE_ROOT}/include/hipSYCL/pcuda/detail/prefixed_runtime.hpp.in
  ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/cuda_prefixed_runtime.hpp)

set(ACPP_PCUDA_PREFIX "hip")
set(ACPP_PCUDA_CAPTIAL_PREFIX "HIP")
configure_file(
  ${ACPP_SOURCE_ROOT}/include/hipSYCL/pcuda/detail/prefixed_runtime.hpp.in
  ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/hip_prefixed_runtime.hpp)


set(ACPP_PCUDA_PREFIX "cuda")
set(ACPP_PCUDA_CAPITAL_PREFIX "CUDA")
configure_file(
  ${ACPP_SOURCE_ROOT}/include/hipSYCL/pcuda/detail/prefixed_runtime.hpp.in
  ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/cuda_prefixed_runtime.hpp)

set(ACPP_PCUDA_PREFIX "hip")
set(ACPP_PCUDA_CAPTIAL_PREFIX "HIP")
configure_file(
  ${ACPP_SOURCE_ROOT}/include/hipSYCL/pcuda/detail/prefixed_runtime.hpp.in
  ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/hip_prefixed_runtime.hpp)



install(DIRECTORY include/CL DESTINATION include/AdaptiveCpp/ FILES_MATCHING PATTERN "*.hpp")
install(DIRECTORY include/SYCL DESTINATION include/AdaptiveCpp/ FILES_MATCHING PATTERN "*.hpp")

install(DIRECTORY include/hipSYCL DESTINATION include/AdaptiveCpp/ FILES_MATCHING PATTERN "*.hpp")
install(DIRECTORY include/hipSYCL DESTINATION include/AdaptiveCpp/ FILES_MATCHING PATTERN "*.h")
install(DIRECTORY include/hipSYCL/std DESTINATION include/AdaptiveCpp/hipSYCL/ )

install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/common/config.hpp DESTINATION include/AdaptiveCpp/hipSYCL/common/)
install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/cuda_prefixed_runtime.hpp DESTINATION include/AdaptiveCpp/hipSYCL/pcuda/detail/)
install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/hip_prefixed_runtime.hpp DESTINATION include/AdaptiveCpp/hipSYCL/pcuda/detail/)

# This part of the installation process can be simplified once the source directory has been
# renamed from hipSYCL to AdaptiveCpp.
install(DIRECTORY include/hipSYCL/ DESTINATION include/AdaptiveCpp/AdaptiveCpp FILES_MATCHING PATTERN "*.hpp")
install(DIRECTORY include/hipSYCL/ DESTINATION include/AdaptiveCpp/AdaptiveCpp FILES_MATCHING PATTERN "*.h")
install(DIRECTORY include/hipSYCL/std/ DESTINATION include/AdaptiveCpp/AdaptiveCpp/std )
install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/common/config.hpp DESTINATION include/AdaptiveCpp/AdaptiveCpp/common/)
install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/cuda_prefixed_runtime.hpp DESTINATION include/AdaptiveCpp/AdaptiveCpp/pcuda/detail/)
install(FILES ${ACPP_BINARY_ROOT}/include/hipSYCL/pcuda/detail/hip_prefixed_runtime.hpp DESTINATION include/AdaptiveCpp/AdaptiveCpp/pcuda/detail/)


if(NOT WIN32)
# Windows is case-insensitive, so don't copy to sycl/sycl.hpp as
# we already have SYCL/sycl.hpp
install(FILES include/SYCL/sycl.hpp DESTINATION include/AdaptiveCpp/sycl/)
endif()
install(PROGRAMS bin/acpp DESTINATION bin)
install(PROGRAMS bin/acpp DESTINATION bin RENAME syclcc)
install(PROGRAMS bin/acpp DESTINATION bin RENAME syclcc-clang)

include(CMakePackageConfigHelpers)

# The install rpath add_sycl_to_target gives applications, under all three
# installed CMake packages below (Commit 6, doc/design-walkthrough-2026-
# 09-25.md, "Resolved opens -> CMake rpaths for apps") - a plain @VAR@
# substitution shared by all three *-config.cmake.in files' configure_
# package_config_file calls, computed once since it does not depend on
# which package is being generated.
acpp_app_install_rpath(ACPP_APP_INSTALL_RPATH_DEFAULT)

# Legacy module (hipSYCL)


set(HIPSYCL_INSTALL_CMAKE_DIR
  "lib/cmake/hipSYCL" CACHE PATH "Install path for legacy CMake config files")

# Set relative paths for install root in the following variables so that
# configure_package_config_file will generate paths relative whatever is
# the future install root
set(HIPSYCL_INSTALL_COMPILER_DIR bin)
set(HIPSYCL_INSTALL_LAUNCHER_DIR ${HIPSYCL_INSTALL_CMAKE_DIR})
set(HIPSYCL_INSTALL_LAUNCHER_RULE_DIR ${HIPSYCL_INSTALL_CMAKE_DIR})

install(PROGRAMS cmake/syclcc-launcher DESTINATION ${HIPSYCL_INSTALL_CMAKE_DIR})
install(PROGRAMS cmake/syclcc-launch.rule.in DESTINATION ${HIPSYCL_INSTALL_CMAKE_DIR})

write_basic_package_version_file(
  "${ACPP_BINARY_ROOT}/hipsycl-config-version.cmake"
  VERSION ${hipSYCL_VERSION}
  COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    ${ACPP_SOURCE_ROOT}/cmake/hipsycl-config.cmake.in
    ${ACPP_BINARY_ROOT}/hipsycl-config.cmake
    INSTALL_DESTINATION ${HIPSYCL_INSTALL_CMAKE_DIR}
    PATH_VARS
    HIPSYCL_INSTALL_COMPILER_DIR
    HIPSYCL_INSTALL_LAUNCHER_DIR
    HIPSYCL_INSTALL_LAUNCHER_RULE_DIR
)

install(FILES
  ${ACPP_BINARY_ROOT}/hipsycl-config.cmake
  ${ACPP_BINARY_ROOT}/hipsycl-config-version.cmake
  DESTINATION ${HIPSYCL_INSTALL_CMAKE_DIR}
)

install(EXPORT install_exports
  FILE "hipsycl-targets.cmake"
  NAMESPACE hipSYCL::
  DESTINATION ${HIPSYCL_INSTALL_CMAKE_DIR}
)

mark_as_advanced(
  HIPSYCL_INSTALL_CMAKE_DIR
)


# Legacy module (Open SYCL)

set(OPENSYCL_INSTALL_CMAKE_DIR
  "lib/cmake/OpenSYCL" CACHE PATH "Install path for CMake config files")

# Set relative paths for install root in the following variables so that
# configure_package_config_file will generate paths relative whatever is
# the future install root
set(OPENSYCL_INSTALL_COMPILER_DIR bin)
set(OPENSYCL_INSTALL_LAUNCHER_DIR ${OPENSYCL_INSTALL_CMAKE_DIR})
set(OPENSYCL_INSTALL_LAUNCHER_RULE_DIR ${OPENSYCL_INSTALL_CMAKE_DIR})

install(PROGRAMS cmake/syclcc-launcher DESTINATION ${OPENSYCL_INSTALL_CMAKE_DIR})
install(PROGRAMS cmake/syclcc-launch.rule.in DESTINATION ${OPENSYCL_INSTALL_CMAKE_DIR})

write_basic_package_version_file(
  "${ACPP_BINARY_ROOT}/opensycl-config-version.cmake"
  VERSION ${hipSYCL_VERSION}
  COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    ${ACPP_SOURCE_ROOT}/cmake/opensycl-config.cmake.in
    ${ACPP_BINARY_ROOT}/opensycl-config.cmake
    INSTALL_DESTINATION ${OPENSYCL_INSTALL_CMAKE_DIR}
    PATH_VARS
    OPENSYCL_INSTALL_COMPILER_DIR
    OPENSYCL_INSTALL_LAUNCHER_DIR
    OPENSYCL_INSTALL_LAUNCHER_RULE_DIR
)

install(FILES
  ${ACPP_BINARY_ROOT}/opensycl-config.cmake
  ${ACPP_BINARY_ROOT}/opensycl-config-version.cmake
  DESTINATION ${OPENSYCL_INSTALL_CMAKE_DIR}
)

install(EXPORT install_exports
  FILE "opensycl-targets.cmake"
  NAMESPACE OpenSYCL::
  DESTINATION ${OPENSYCL_INSTALL_CMAKE_DIR}
)

mark_as_advanced(
  OPENSYCL_INSTALL_CMAKE_DIR
)

# New module


set(ADAPTIVECPP_INSTALL_CMAKE_DIR
  "lib/cmake/AdaptiveCpp" CACHE PATH "Install path for CMake config files")

# Set relative paths for install root in the following variables so that
# configure_package_config_file will generate paths relative whatever is
# the future install root
set(ADAPTIVECPP_INSTALL_COMPILER_DIR bin)
set(ADAPTIVECPP_INSTALL_LAUNCHER_DIR ${ADAPTIVECPP_INSTALL_CMAKE_DIR})
set(ADAPTIVECPP_INSTALL_LAUNCHER_RULE_DIR ${ADAPTIVECPP_INSTALL_CMAKE_DIR})

install(PROGRAMS cmake/syclcc-launcher DESTINATION ${ADAPTIVECPP_INSTALL_CMAKE_DIR})
install(PROGRAMS cmake/syclcc-launch.rule.in DESTINATION ${ADAPTIVECPP_INSTALL_CMAKE_DIR})

write_basic_package_version_file(
  "${ACPP_BINARY_ROOT}/adaptivecpp-config-version.cmake"
  VERSION ${hipSYCL_VERSION}
  COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    ${ACPP_SOURCE_ROOT}/cmake/adaptivecpp-config.cmake.in
    ${ACPP_BINARY_ROOT}/adaptivecpp-config.cmake
    INSTALL_DESTINATION ${ADAPTIVECPP_INSTALL_CMAKE_DIR}
    PATH_VARS
    ADAPTIVECPP_INSTALL_COMPILER_DIR
    ADAPTIVECPP_INSTALL_LAUNCHER_DIR
    ADAPTIVECPP_INSTALL_LAUNCHER_RULE_DIR
)

install(FILES
  ${ACPP_BINARY_ROOT}/adaptivecpp-config.cmake
  ${ACPP_BINARY_ROOT}/adaptivecpp-config-version.cmake
  DESTINATION ${ADAPTIVECPP_INSTALL_CMAKE_DIR}
)

install(EXPORT install_exports
  FILE "adaptivecpp-targets.cmake"
  NAMESPACE AdaptiveCpp::
  DESTINATION ${ADAPTIVECPP_INSTALL_CMAKE_DIR}
)

mark_as_advanced(
  ADAPTIVECPP_INSTALL_CMAKE_DIR
)

