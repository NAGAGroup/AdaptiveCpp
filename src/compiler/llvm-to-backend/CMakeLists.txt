
set(LLVM_TO_BACKEND_INCLUDE_DIRS
  ../../../include
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${ACPP_BINARY_ROOT}/include)

set(CMAKE_INSTALL_RPATH ${base} ${base}/../../)

function(create_llvm_based_library)
  set(options STATIC)
  set(one_value_keywords TARGET)
  set(multi_value_keywords SOURCES)
  cmake_parse_arguments(CREATE_LLVM_LIBRARY
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
    ${ARGN}
  )

  set(target ${CREATE_LLVM_LIBRARY_TARGET})
  set(sources ${CREATE_LLVM_LIBRARY_SOURCES})

  if(CREATE_LLVM_LIBRARY_STATIC)
    add_library(${target} STATIC
      ${sources})
  else()
    add_library(${target} SHARED
      ${sources})
  endif()

  target_include_directories(${target} PRIVATE
    ${LLVM_TO_BACKEND_INCLUDE_DIRS})
  target_include_directories(${target} SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})

  separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
  target_compile_definitions(${target} PRIVATE
    ${LLVM_DEFINITIONS_LIST})
  target_compile_definitions(${target} PRIVATE -DHIPSYCL_COMPILER_COMPONENT)

  if(NOT ACPP_LLVM_COMPONENT)
    find_library(LLVM_LIBRARY NAMES LLVM LLVM-${LLVM_VERSION_MAJOR} HINTS ${LLVM_LIBRARY_DIRS} NO_DEFAULT_PATH)
    if(NOT LLVM_LIBRARY)
      message(FATAL_ERROR "LLVM at ${LLVM_DIR} does not have libLLVM.so. Disable advanced compiler-based functionality (-DACPP_COMPILER_FEATURE_PROFILE=minimal, not recommended for most use cases) or choose another LLVM installation")
    endif()
  elseif(NOT LLVM_BUILD_LLVM_DYLIB AND NOT WIN32)
    message(FATAL_ERROR "LLVM is not configured to build libLLVM.so. Please disable reconfigure with LLVM_BUILD_LLVM_DYLIB and LLVM_LINK_LLVM_DYLIB.")
  endif()
  if(WIN32)
    llvm_config(${target} core support irreader passes)
  else()
    llvm_config(${target} USE_SHARED core support irreader passes)
  endif()
  # We need symbolic functions for stdpar
  target_link_libraries(${target} PRIVATE ${HIPSYCL_STDPAR_RT_LINKER_FLAGS})

  if(NOT LLVM_ENABLE_EH)
    target_compile_options(${target} PRIVATE -fno-exceptions)
  endif()
  if(NOT LLVM_ENABLE_RTTI)
    target_compile_options(${target} PRIVATE -fno-rtti)
  endif()

  if(ACPP_LLVM_COMPONENT)
    add_dependencies(${target} intrinsics_gen)
  endif()

  set(install_subdir hipSYCL/llvm-to-backend)
  install(TARGETS ${target}
    RUNTIME DESTINATION bin/${install_subdir}
    LIBRARY DESTINATION lib/${install_subdir}
    ARCHIVE DESTINATION lib/${install_subdir})
endfunction()

function(create_llvm_to_backend_library)
  set(options)
  set(one_value_keywords TARGET)
  set(multi_value_keywords SOURCES)
  cmake_parse_arguments(CREATE_LLVM_LIBRARY
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
    ${ARGN}
  )

  set(target ${CREATE_LLVM_LIBRARY_TARGET})
  set(sources ${CREATE_LLVM_LIBRARY_SOURCES})

  if(WIN32)
    set(MODE STATIC)
  endif()
  create_llvm_based_library(TARGET ${target} ${MODE} SOURCES ${sources})
  target_link_libraries(${target} PUBLIC llvm-to-backend)
endfunction()

function(create_llvm_to_backend_tool)
  set(options)
  set(one_value_keywords TARGET)
  set(multi_value_keywords SOURCES)
  cmake_parse_arguments(CREATE_LLVM_TOOL
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
    ${ARGN}
  )

  set(target ${CREATE_LLVM_TOOL_TARGET})
  set(sources ${CREATE_LLVM_TOOL_SOURCES})

  add_executable(${target}-tool ${sources})

  target_include_directories(${target}-tool PRIVATE
    ${LLVM_TO_BACKEND_INCLUDE_DIRS})
  target_include_directories(${target}-tool SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})

  separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
  target_compile_definitions(${target}-tool PRIVATE
    ${LLVM_DEFINITIONS_LIST})
  target_compile_definitions(${target}-tool PRIVATE -DHIPSYCL_TOOL_COMPONENT)
  target_link_libraries(${target}-tool PRIVATE ${target})

  set(install_subdir hipSYCL/llvm-to-backend)
  install(TARGETS ${target}-tool
    RUNTIME DESTINATION bin/${install_subdir}
    LIBRARY DESTINATION lib/${install_subdir}
    ARCHIVE DESTINATION lib/${install_subdir})
endfunction()

function(add_hipsycl_llvm_backend)
  set(options)
  set(one_value_keywords BACKEND)
  set(multi_value_keywords LIBRARY TOOL)
  cmake_parse_arguments(ADD_BACKEND
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
    ${ARGN}
  )

  set(backend_name ${ADD_BACKEND_BACKEND})
  set(tool_sources ${ADD_BACKEND_TOOL})
  set(library_sources ${ADD_BACKEND_LIBRARY})

  create_llvm_to_backend_library(TARGET llvm-to-${backend_name} SOURCES ${library_sources})
  create_llvm_to_backend_tool(TARGET llvm-to-${backend_name} SOURCES ${tool_sources})
endfunction()

include(ExternalProject)

if(WITH_SSCP_COMPILER)
  if(WIN32)
    set(MODE STATIC)
  endif()
  create_llvm_based_library(
    ${MODE}
    TARGET llvm-to-backend
    SOURCES
      LLVMToBackend.cpp
      AddressSpaceInferencePass.cpp
      KnownGroupSizeOptPass.cpp
      KnownPtrParamAlignmentOptPass.cpp
      GlobalSizesFitInI32OptPass.cpp
      GlobalInliningAttributorPass.cpp
      DeadArgumentEliminationPass.cpp
      ProcessS2ReflectionPass.cpp
      ../sscp/KernelOutliningPass.cpp
      Utils.cpp
      )

  target_compile_definitions(llvm-to-backend PRIVATE
    -DACPP_CLANG_PATH="${CLANG_INSTALLED_PATH}"
  )
  target_link_libraries(llvm-to-backend PUBLIC
    acpp-common
  )

  if(WITH_LLVM_TO_SPIRV)
    add_hipsycl_llvm_backend(
      BACKEND spirv
      LIBRARY spirv/LLVMToSpirv.cpp
      TOOL spirv/LLVMToSpirvTool.cpp)

    # Install LLVM-SPIRV translator for llvm-to-spirv
    # The translator is configured by a SEPARATE cmake invocation, which
    # inherits nothing from this one: not the sysroot, not CMAKE_FIND_ROOT_PATH
    # and its modes, not the toolchain binaries. Left to itself it searches the
    # machine, and on a host with a distribution LLVM installed it will find
    # that one rather than the LLVM being built alongside it.
    #
    # Only the caller knows what its environment requires, so this is where it
    # says so. Empty by default: nothing changes for a build that does not set
    # it. Use | to separate elements of any value that is itself a list.
    set(ACPP_SPIRV_CMAKE_ARGS "" CACHE STRING
      "Additional cmake arguments for the SPIR-V translator sub-build, which inherits nothing from this configure. Separate list elements with | rather than ;.")

    if(NOT LLVMSPIRV_BRANCH)
      set(LLVMSPIRV_BRANCH llvm_release_${LLVM_VERSION_MAJOR}0)
    endif()
    # A branch is resolved when the build runs, so two builds of the same
    # AdaptiveCpp source can end up with different translators, and nothing
    # records which one was used. LLVMSPIRV_COMMIT pins it instead. A shallow
    # clone cannot generally fetch an arbitrary commit, so pinning fetches in
    # full.
    if(LLVMSPIRV_COMMIT)
      set(LLVMSPIRV_GIT_TAG ${LLVMSPIRV_COMMIT})
      set(LLVMSPIRV_GIT_SHALLOW OFF)
    else()
      set(LLVMSPIRV_GIT_TAG origin/${LLVMSPIRV_BRANCH})
      set(LLVMSPIRV_GIT_SHALLOW ON)
    endif()
    set(LLVMSPIRV_RELATIVE_INSTALLDIR lib/hipSYCL/ext/llvm-spirv)
    set(LLVMSPIRV_INSTALLDIR ${CMAKE_INSTALL_PREFIX}/${LLVMSPIRV_RELATIVE_INSTALLDIR})
    set(LLVMSPIRV_PATH ${LLVMSPIRV_INSTALLDIR}/bin/llvm-spirv)
    if(WIN32)
      set(LLVMSPIRV_EXECUTABLE_NAME "llvm-spirv.exe")
    else()
      set(LLVMSPIRV_EXECUTABLE_NAME "llvm-spirv")
    endif()
    set(LLVMSPIRV_RELATIVE_PATH ${LLVMSPIRV_RELATIVE_INSTALLDIR}/bin/${LLVMSPIRV_EXECUTABLE_NAME})

    ExternalProject_Add(LLVMSpirvTranslator
      # ACPP_SPIRV_CMAKE_ARGS may carry values that are themselves lists, so
      # the separator has to be something other than the semicolon
      # ExternalProject_Add uses to split its own arguments.
      LIST_SEPARATOR |
      GIT_REPOSITORY https://github.com/AdaptiveCpp/SPIRV-LLVM-Translator
      GIT_TAG ${LLVMSPIRV_GIT_TAG}
      GIT_SHALLOW ${LLVMSPIRV_GIT_SHALLOW}
      GIT_REMOTE_UPDATE_STRATEGY CHECKOUT
      BUILD_ALWAYS OFF
      BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/ext/llvm-spirv
      CMAKE_ARGS
        -DCMAKE_C_COMPILER:PATH=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER:PATH=${CMAKE_CXX_COMPILER}
        -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
        ${ACPP_SPIRV_CMAKE_ARGS}
      CMAKE_CACHE_ARGS
        -DLLVM_SPIRV_BUILD_EXTERNAL:BOOL=YES
        -DLLVM_DIR:PATH=${LLVM_DIR}
        -DCMAKE_INSTALL_PREFIX:PATH=${LLVMSPIRV_INSTALLDIR}
        -DCMAKE_CXX_FLAGS:STRING=${CMAKE_CXX_FLAGS}
      BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${ACPP_SUBPROJECT_PARALLEL_JOBS}
      INSTALL_COMMAND ""
    )

    add_custom_target(InstallLLVMSpirvTranslator
      COMMAND ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR}/ext/llvm-spirv --target install
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/ext/llvm-spirv
    )

    #install(TARGETS InstallLLVMSpirvTranslator)
    install(CODE [[
      execute_process(COMMAND "${CMAKE_COMMAND}" --build . --target InstallLLVMSpirvTranslator)
    ]])

    add_dependencies(llvm-to-spirv LLVMSpirvTranslator)
    target_compile_definitions(llvm-to-spirv PRIVATE
      -DHIPSYCL_LLVMSPIRV_NAME="${LLVMSPIRV_EXECUTABLE_NAME}"
      -DHIPSYCL_RELATIVE_LLVMSPIRV_PATH="${LLVMSPIRV_RELATIVE_PATH}")
  endif()

  if(WITH_LLVM_TO_PTX)
    add_hipsycl_llvm_backend(
      BACKEND ptx
      LIBRARY ptx/LLVMToPtx.cpp
      TOOL ptx/LLVMToPtxTool.cpp)

    # HIPSYCL_CUDA_PATH is not defined here: no translation unit reads it, and
    # compiling it in put the build machine's CUDA installation path into
    # libllvm-to-ptx.so as a string literal for nothing.
    target_compile_definitions(llvm-to-ptx PRIVATE
      -DACPP_CUDA_DEVICE_LIBS_PATH="${CUDA_DEVICE_LIBS_PATH}")
  endif()

  if(WITH_LLVM_TO_AMDGPU_AMDHSA)
    add_hipsycl_llvm_backend(
      BACKEND amdgpu
      LIBRARY amdgpu/LLVMToAmdgpu.cpp
      TOOL amdgpu/LLVMToAmdgpuTool.cpp)

    # ACPP_ROCM_PATH is not defined here, for the same reason as
    # HIPSYCL_CUDA_PATH above. The name survives elsewhere as a link-line
    # placeholder and as a driver setting; only the compile definition was dead.
    target_compile_definitions(llvm-to-amdgpu PRIVATE
      -DACPP_ROCM_DEVICE_LIBS_PATH="${ROCM_DEVICE_LIBS_PATH}")

    # hipcc is found in the root CMakeLists, above cmake/options.cmake; the
    # legacy fallback there may already have found it while deciding whether
    # ROCm is available at all. find results are cache entries, so
    # HIPCC_COMPILER is visible here.
    if(HIPCC_COMPILER)
      target_compile_definitions(llvm-to-amdgpu PRIVATE
        -DACPP_HIPCC_PATH="${HIPCC_COMPILER}")
    endif()

    find_library(HIPRTC_LIBRARY hiprtc HINTS ${ROCM_PATH}/lib)

    if(HIPRTC_LIBRARY)
      message(STATUS "Found hipRTC: ${HIPRTC_LIBRARY}")

      target_include_directories(llvm-to-amdgpu PRIVATE ${ROCM_PATH}/include)
      target_link_libraries(llvm-to-amdgpu PRIVATE ${HIPRTC_LIBRARY})
      target_compile_definitions(llvm-to-amdgpu PRIVATE -DACPP_HIPRTC_LINK)
    endif()

  endif()


  if(WITH_LLVM_TO_HOST)
    # The CPU flags and additional JIT flags are configuration entries
    # (ACPP_LLC_HOST_CPU_FLAG and friends in cmake/options.cmake). The default
    # -mcpu=native is resolved by llc on the machine doing the JIT, so nothing
    # about the build machine is recorded; pinning a CPU is
    # -DACPP_LLC_HOST_CPU_FLAG="-mcpu=<cpu>" at configure time, or the entry
    # at run time.
    message(STATUS "llvm-to-host: Using llc compilation flag to target native CPU: ${ACPP_LLC_HOST_CPU_FLAG}")

    add_hipsycl_llvm_backend(
      BACKEND host
      LIBRARY host/LLVMToHost.cpp host/HostKernelWrapperPass.cpp host/StaticLocalMemoryPass.cpp
      TOOL host/LLVMToHostTool.cpp)

    target_compile_definitions(llvm-to-host PRIVATE
      -DACPP_LLC_HOST_CPU_FLAG="${ACPP_LLC_HOST_CPU_FLAG}"
      -DACPP_OPT_HOST_CPU_FLAG="${ACPP_OPT_HOST_CPU_FLAG}"
      -DACPP_LLC_ADDITIONAL_FLAGS="${ACPP_LLC_ADDITIONAL_FLAGS}"
      -DACPP_OPT_ADDITIONAL_FLAGS="${ACPP_OPT_ADDITIONAL_FLAGS}")
    target_link_libraries(llvm-to-host PRIVATE acpp-clang-cbs)
  endif()

  if(WITH_LLVM_TO_METAL)
    add_hipsycl_llvm_backend(
      BACKEND metal
      LIBRARY
        metal/LLVMToMetal.cpp
        metal/HLExtractionPass.cpp
        metal/PointerTranslationAnnotationPass.cpp
        metal/PointerTranslationPass.cpp
        metal/HLTree.cpp
        metal/Emitter.cpp
      TOOL metal/LLVMToMetalTool.cpp)
  endif()

  if(WITH_LLVM_TO_VULKAN)
    add_hipsycl_llvm_backend(
      BACKEND clspv
      LIBRARY clspv/LLVMToCLSPV.cpp
      clspv/AddrSpaceCastRemovalPass.cpp
      clspv/FoldChainedGEPsPass.cpp
      clspv/RemoveUnusedIntrinsicsPass.cpp
      clspv/MemsetLoweringPass.cpp
      clspv/ConstantAddrSpacePass.cpp
      TOOL clspv/LLVMToCLSPVTool.cpp)

    find_program(CLSPV_COMPILER NAMES clspv REQUIRED)

    message(STATUS "Using clspv at: ${CLSPV_COMPILER}")
    target_compile_definitions(llvm-to-clspv PRIVATE
      -DHIPSYCL_CLSPV_PATH="${CLSPV_COMPILER}")
  endif()

endif()
