
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
    if(CMAKE_CROSSCOMPILING)
      find_library(LLVM_LIBRARY NAMES LLVM LLVM-${LLVM_VERSION_MAJOR} HINTS ${LLVM_LIBRARY_DIRS} NO_CMAKE_FIND_ROOT_PATH)
    else()
      find_library(LLVM_LIBRARY NAMES LLVM LLVM-${LLVM_VERSION_MAJOR} HINTS ${LLVM_LIBRARY_DIRS} NO_DEFAULT_PATH)
    endif()
    if(NOT LLVM_LIBRARY)
      message(FATAL_ERROR "LLVM at ${LLVM_DIR} does not have libLLVM.so. Disable advanced compiler-based functionality (-DACPP_COMPILER_FEATURE_PROFILE=minimal, not recommended for most use cases) or choose another LLVM installation")
    endif()
  elseif(NOT LLVM_BUILD_LLVM_DYLIB AND NOT WIN32)
    message(FATAL_ERROR "LLVM is not configured to build libLLVM.so. Please disable reconfigure with LLVM_BUILD_LLVM_DYLIB and LLVM_LINK_LLVM_DYLIB.")
  endif()
  # When LLVM is a DLL (Windows LLVM_LINK_LLVM_DYLIB), link the DLL like
  # LLVM's own tools do; linking the static component libraries against
  # headers that declare dllimport broke the llvm-to-*-tool links
  # (duplicate std::ctype<char>::_Getcat).
  if(WIN32 AND NOT LLVM_LINK_LLVM_DYLIB)
    llvm_config(${target} core support irreader passes)
  else()
    llvm_config(${target} USE_SHARED core support irreader passes)
  endif()
  # Match how LLVM compiled its DLL (AddLLVM.cmake: /Zc:dllexportInlines- for
  # clang-cl with LLVM_BUILD_LLVM_DYLIB_VIS), or inline members are imported
  # from a DLL that does not export them.
  if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES Clang AND LLVM_BUILD_LLVM_DYLIB_VIS
     AND NOT LLVM_DYLIB_EXPORT_INLINES)
    target_compile_options(${target} PRIVATE /Zc:dllexportInlines-)
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
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}/${install_subdir}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/${install_subdir}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/${install_subdir})
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
  # Match how LLVM compiled its DLL (AddLLVM.cmake: /Zc:dllexportInlines- for
  # clang-cl with LLVM_BUILD_LLVM_DYLIB_VIS), or inline members are imported
  # from a DLL that does not export them.
  if(MSVC AND CMAKE_CXX_COMPILER_ID MATCHES Clang AND LLVM_BUILD_LLVM_DYLIB_VIS
     AND NOT LLVM_DYLIB_EXPORT_INLINES)
    target_compile_options(${target}-tool PRIVATE /Zc:dllexportInlines-)
  endif()

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
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}/${install_subdir}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/${install_subdir}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/${install_subdir})
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

  target_link_libraries(llvm-to-backend PUBLIC
    acpp-common
  )
  # getLibMvecDir() (Utils.cpp, linux only) asks the loader via dlopen/dlinfo.
  # Before glibc 2.34 those live in libdl, not libc, and acpp-common's own
  # dl link is PRIVATE, so it does not carry over. Empty where libc has them.
  target_link_libraries(llvm-to-backend PRIVATE ${CMAKE_DL_LIBS})

  # The JIT finds the LLVM tools this build installs (llc, opt, lld, clang++)
  # in CMAKE_INSTALL_BINDIR, relative to the runtime library's own install
  # directory - the same anchor and the same platform choice as
  # ACPP_RT_LIB_DIR_TO_APP_CONFIG in src/common/CMakeLists.txt. Empty where
  # the runtime library itself sits in the bin directory (Windows).
  if(WIN32)
    set(_acpp_rt_libdir_for_bin "${CMAKE_INSTALL_BINDIR}")
  else()
    set(_acpp_rt_libdir_for_bin "${CMAKE_INSTALL_LIBDIR}")
  endif()
  set(_acpp_bin_anchor "/acpp-bin-dir-anchor")
  file(RELATIVE_PATH ACPP_RT_LIB_DIR_TO_BIN_DIR
    "${_acpp_bin_anchor}/${_acpp_rt_libdir_for_bin}"
    "${_acpp_bin_anchor}/${CMAKE_INSTALL_BINDIR}")
  target_compile_definitions(llvm-to-backend PRIVATE
    -DACPP_RT_LIB_DIR_TO_BIN_DIR="${ACPP_RT_LIB_DIR_TO_BIN_DIR}")

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
    # Windows: executables and the DLLs they load live under bindir, and the
    # runtime's own directory ($ACPP_RT_LIB_DIR) IS bindir there, which is
    # where cmake/options/windows/common/core.cmake declares llvm-spirv.
    if(WIN32)
      set(LLVMSPIRV_RELATIVE_INSTALLDIR ${CMAKE_INSTALL_BINDIR}/hipSYCL/ext/llvm-spirv)
    else()
      set(LLVMSPIRV_RELATIVE_INSTALLDIR ${CMAKE_INSTALL_LIBDIR}/hipSYCL/ext/llvm-spirv)
    endif()
    set(LLVMSPIRV_INSTALLDIR ${CMAKE_INSTALL_PREFIX}/${LLVMSPIRV_RELATIVE_INSTALLDIR})
    set(LLVMSPIRV_PATH ${LLVMSPIRV_INSTALLDIR}/bin/llvm-spirv)

    ExternalProject_Add(LLVMSpirvTranslator
      # ACPP_SPIRV_CMAKE_ARGS may carry values that are themselves lists, so
      # the separator has to be something other than the semicolon
      # ExternalProject_Add uses to split its own arguments.
      LIST_SEPARATOR |
      GIT_REPOSITORY https://github.com/NAGAGroup/SPIRV-LLVM-Translator
      GIT_TAG ${LLVMSPIRV_GIT_TAG}
      GIT_SHALLOW ${LLVMSPIRV_GIT_SHALLOW}
      GIT_REMOTE_UPDATE_STRATEGY CHECKOUT
      # The translator's test tree has paths beyond MAX_PATH; the win-64 clone hit 17
      # "Filename too long" checkout errors.
      GIT_CONFIG core.longpaths=true
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
  endif()

  if(WITH_LLVM_TO_PTX)
    add_hipsycl_llvm_backend(
      BACKEND ptx
      LIBRARY ptx/LLVMToPtx.cpp
      TOOL ptx/LLVMToPtxTool.cpp)
  endif()

  if(WITH_LLVM_TO_AMDGPU_AMDHSA)
    add_hipsycl_llvm_backend(
      BACKEND amdgpu
      LIBRARY amdgpu/LLVMToAmdgpu.cpp
      TOOL amdgpu/LLVMToAmdgpuTool.cpp)

    find_library(HIPRTC_LIBRARY hiprtc HINTS "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_LIBDIR}")

    if(HIPRTC_LIBRARY)
      message(STATUS "Found hipRTC: ${HIPRTC_LIBRARY}")

      target_include_directories(llvm-to-amdgpu PRIVATE "${ACPP_DISCOVERED_HIP_PREFIX}/${ACPP_DISCOVERED_HIP_INCDIR}")
      target_link_libraries(llvm-to-amdgpu PRIVATE ${HIPRTC_LIBRARY})
      target_compile_definitions(llvm-to-amdgpu PRIVATE -DACPP_HIPRTC_LINK)

      # Reaches a SHIPPED hiprtc (HIP:RT - libhiprtc lives alongside the
      # rest of the ROCm runtime libraries) relative to this target's own
      # install directory, which create_llvm_based_library sets to
      # lib/hipSYCL/llvm-to-backend (install_subdir, above).
      acpp_add_vendor_rpaths(llvm-to-amdgpu FROM "${CMAKE_INSTALL_LIBDIR}/hipSYCL/llvm-to-backend" ENTRIES HIP:RT)
    endif()

  endif()


  if(WITH_LLVM_TO_HOST)
    # The CPU flags and additional JIT flags are run-time settings read by
    # LLVMToHost.cpp (jit_host_llc_cpu_flag, jit_host_opt_cpu_flag,
    # jit_host_llc_flags, jit_host_opt_flags), not compile definitions. Their
    # defaults (-mcpu=native / --mcpu=native) are the configure-time options
    # ACPP_JIT_HOST_* (cmake/options/common/core.cmake) written into acpp-app.cfg.

    add_hipsycl_llvm_backend(
      BACKEND host
      LIBRARY host/LLVMToHost.cpp host/HostKernelWrapperPass.cpp host/StaticLocalMemoryPass.cpp
      TOOL host/LLVMToHostTool.cpp)

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

  endif()

endif()
