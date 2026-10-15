if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  message("-- AdaptiveCpp: Linking AdaptiveCpp into LLVM tools")
  set(COMPILER_LIBRARY_NAME "AdaptiveCpp")
else()
  set(COMPILER_LIBRARY_NAME "acpp-clang")
endif()

if(NOT ACPP_LLVM_COMPONENT)
  cmake_minimum_required(VERSION 3.10)
  project(acpp-clang)
else()
  add_compile_definitions(ACPP_LLVM_COMPONENT)
endif()

if(NOT DEFINED HIPSYCL_DEBUG_LEVEL)
  message(FATAL_ERROR "HIPSYCL_DEBUG_LEVEL was not defined by the top-level CMakeLists.txt.")
endif()

# llc/opt/lld/clang locations are not build-machine facts: the runtime resolves
# them at run time (environment, installed app config, bundled path) in
# Utils.cpp.
add_definitions(-DHIPSYCL_DEBUG_LEVEL=${HIPSYCL_DEBUG_LEVEL})
if(WITH_ACCELERATED_CPU)
  add_definitions(-DHIPSYCL_WITH_ACCELERATED_CPU)
endif()

# Vector math libraries need no compile definitions: the JIT reads which one to use and where it lives from the configuration at run time.

if(WITH_ACCELERATED_CPU OR WITH_SSCP_COMPILER)
  set(CBS_PLUGIN cbs/LoopSplitterInlining.cpp
    cbs/SplitterAnnotationAnalysis.cpp
    cbs/IRUtils.cpp
    cbs/KernelFlattening.cpp
    cbs/LoopsParallelMarker.cpp
    cbs/PHIsToAllocas.cpp
    cbs/RemoveBarrierCalls.cpp
    cbs/CanonicalizeBarriers.cpp
    cbs/SimplifyKernel.cpp
    cbs/LoopSimplify.cpp
    cbs/PipelineBuilder.cpp
    cbs/SubCfgFormation.cpp
    cbs/UniformityAnalysis.cpp
    cbs/VectorShape.cpp
    cbs/VectorizationInfo.cpp
    cbs/AllocaSSA.cpp
    cbs/VectorShapeTransformer.cpp
    cbs/Region.cpp
    cbs/SyncDependenceAnalysis.cpp)

  if(ACPP_LLVM_COMPONENT)
    add_llvm_component_library(acpp-clang-cbs OBJECT
      ${CBS_PLUGIN}
      PARTIAL_SOURCES_INTENDED)
  else()
    add_library(acpp-clang-cbs OBJECT
      ${CBS_PLUGIN}
    )
  endif()

  set_property(TARGET acpp-clang-cbs PROPERTY POSITION_INDEPENDENT_CODE ON)
endif()

if(WITH_ACCELERATED_CPU)
  set(WITH_REFLECTION_BUILTINS ON)
endif()

if(WITH_SSCP_COMPILER)
  set(WITH_REFLECTION_BUILTINS ON)
  set(SSCP_COMPILER
    sscp/KernelOutliningPass.cpp
    sscp/IRConstantReplacer.cpp
    sscp/DynamicFunctionSupport.cpp
    sscp/TargetSeparationPass.cpp
    sscp/HostKernelNameExtractionPass.cpp
    sscp/AggregateArgumentExpansionPass.cpp
    sscp/StdBuiltinRemapperPass.cpp
    sscp/StdAtomicRemapperPass.cpp
    sscp/DeviceAssertPass.cpp
    sscp/HcfRegistrationPass.cpp
    sscp/pcuda/FreeKernelCall.cpp
    sscp/pcuda/StaticLocalMemoryPass.cpp
    sscp/pcuda/ExternDynamicLocalMemoryPass.cpp)
  add_definitions(-DHIPSYCL_WITH_SSCP_COMPILER)
else()
  set(SSCP_COMPILER "")
endif()

if(WITH_STDPAR_COMPILER)
  set(WITH_REFLECTION_BUILTINS ON)
  set(STDPAR_COMPILER
    stdpar/MallocToUSM.cpp
    stdpar/SyncElision.cpp)
  add_definitions(-DHIPSYCL_WITH_STDPAR_COMPILER)
else()
  set(STDPAR_COMPILER "")
endif()

if(WITH_REFLECTION_BUILTINS)
  set(REFLECTION_BUILTINS
    reflection/IntrospectStructPass.cpp
    reflection/FunctionNameExtractionPass.cpp)
  add_definitions(-DHIPSYCL_WITH_REFLECTION_BUILTINS)
else()
  set(REFLECTION_BUILTINS "")
endif()

set(COMPILER_LIBRARY_SOURCES
  AdaptiveCppLlvmPasses.cpp
  GlobalsPruningPass.cpp
  SMCPCompatPass.cpp
  ${SSCP_COMPILER}
  ${STDPAR_COMPILER}
  ${REFLECTION_BUILTINS}
)

if(NOT ACPP_LLVM_COMPONENT)
  if(WIN32)
    add_library(${COMPILER_LIBRARY_NAME} SHARED
      ${COMPILER_LIBRARY_SOURCES}
      frontend/AdaptiveCppClangPlugin.cpp
    )
  else()
    add_library(${COMPILER_LIBRARY_NAME} MODULE
      ${COMPILER_LIBRARY_SOURCES}
      frontend/AdaptiveCppClangPlugin.cpp
    )
  endif()
else()
  add_clang_library(acpp-frontend OBJECT
    frontend/AdaptiveCppClangPlugin.cpp
    PARTIAL_SOURCES_INTENDED)
  set_property(TARGET acpp-frontend PROPERTY POSITION_INDEPENDENT_CODE ON)
  target_include_directories(obj.acpp-frontend PRIVATE
    ${LLVM_MAIN_SRC_DIR}/../clang/include
    ${LLVM_BINARY_DIR}/tools/clang/include
  )
  add_dependencies(obj.acpp-frontend clang-tablegen-targets)

  if(${CLANG_LINK_CLANG_DYLIB})
    set_property(
        TARGET clang-cpp
        APPEND PROPERTY
            LINK_LIBRARIES obj.acpp-frontend
    )
  else()
    set_property(
        TARGET clang
        APPEND PROPERTY
            LINK_LIBRARIES obj.acpp-frontend
    )
  endif()

  add_llvm_pass_plugin(${COMPILER_LIBRARY_NAME}
    NO_MODULE
    SUBPROJECT AdaptiveCpp
    ${COMPILER_LIBRARY_SOURCES}
  )
  # add_llvm_pass_plugin puts LLVM_<NAME>_LINK_INTO_TOOLS on `${name}` (AddLLVM.cmake:1328). For
  # an OBJECT llvm library that target is only the static wrapper (AddLLVM.cmake:646-732); the
  # sources compile in `obj.${name}`, so the macro never reached AdaptiveCppLlvmPasses.cpp. As a
  # result the Windows dllexport of getAdaptiveCppPluginInfo never applied (opt.exe still
  # undefined on win-64 and win-arm64), and the
  # `#ifndef LLVM_ADAPTIVECPP_LINK_INTO_TOOLS` llvmGetPassPluginInfo was wrongly compiled into LLVM
  # itself.
  if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
    target_compile_definitions(obj.${COMPILER_LIBRARY_NAME} PRIVATE LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  endif()
endif()

function(configure_target)
  set(options)
  set(one_value_keywords TARGET)
  set(multi_value_keywords)
  cmake_parse_arguments(CONFIGURE_LLVM_TARGET
    "${options}"
    "${one_value_keywords}"
    "${multi_value_keywords}"
    ${ARGN}
  )

  set(target ${CONFIGURE_LLVM_TARGET_TARGET})

  target_include_directories(${target} PRIVATE
    ${ACPP_SOURCE_ROOT}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${ACPP_BINARY_ROOT}/include)
  target_include_directories(${target} SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})

  separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
  target_compile_definitions(${target} PRIVATE
    ${LLVM_DEFINITIONS_LIST})
  target_compile_definitions(${target} PRIVATE
    -DHIPSYCL_COMPILER_COMPONENT)

  if(ROCM_VERSION_MAJOR)
    target_compile_definitions(${target} PRIVATE -DROCM_CLANG_VERSION_MAJOR=${ROCM_VERSION_MAJOR} -DROCM_CLANG_VERSION_MINOR=${ROCM_VERSION_MINOR} -DROCM_CLANG_VERSION_PATCH=${ROCM_VERSION_PATCH})
  endif()

  if(NOT ACPP_LLVM_COMPONENT)
    if(NOT ${LLVM_ENABLE_EH})
      target_compile_options(${target} PRIVATE -fno-exceptions)
    endif()

    if(NOT ${LLVM_ENABLE_RTTI})
      target_compile_options(${target} PRIVATE -fno-rtti)
    endif()

    target_link_libraries(${target} PRIVATE
      ${LLVM_LIBS})
  endif()

  if(WIN32 AND NOT ACPP_LLVM_COMPONENT)
    set(CLANG_LIBRARY_DIR ${LLVM_PREFIX_DIR}/lib/)
    target_link_directories(${target} PRIVATE ${CLANG_LIBRARY_DIR})
    target_link_libraries(${target} PRIVATE clang LLVMSupport)
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Android" AND NOT ACPP_LLVM_COMPONENT)
    find_library(CLANG_LIBRARY NAMES clang-cpp HINTS ${LLVM_LIBRARY_DIRS} NO_CMAKE_FIND_ROOT_PATH)
    if (NOT CLANG_LIBRARY)
      message(FATAL_ERROR "${target} can't link to clang-cpp at ${LLVM_LIBRARY_DIRS}")
    endif()
    target_link_libraries(${target} PRIVATE ${CLANG_LIBRARY} LLVMSupport)
  endif()

  if(ACPP_LLVM_COMPONENT)
    add_dependencies(${target} intrinsics_gen)
  endif()

  install(TARGETS ${target}
          LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
          RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
          ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
endfunction(configure_target)

if(ACPP_LLVM_COMPONENT)
  configure_target(TARGET obj.${COMPILER_LIBRARY_NAME})
  configure_target(TARGET obj.acpp-frontend)
else()
  configure_target(TARGET ${COMPILER_LIBRARY_NAME})
endif()

if (WITH_ACCELERATED_CPU OR WITH_SSCP_COMPILER)
  if(ACPP_LLVM_COMPONENT)
    configure_target(TARGET obj.acpp-clang-cbs)
  else()
    configure_target(TARGET acpp-clang-cbs)
  endif()

  target_link_libraries(${COMPILER_LIBRARY_NAME} PUBLIC acpp-clang-cbs)
endif()


if(APPLE)
  target_link_libraries(${COMPILER_LIBRARY_NAME} PRIVATE -Wl,-undefined -Wl,dynamic_lookup)
elseif(WIN32)
  set_target_properties(${COMPILER_LIBRARY_NAME} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS On)
else()
  target_link_libraries(${COMPILER_LIBRARY_NAME} PRIVATE -Wl,-znodelete)
endif()


add_subdirectory(llvm-to-backend)
