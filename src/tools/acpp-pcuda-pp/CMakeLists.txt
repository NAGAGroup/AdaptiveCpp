add_executable(acpp-pcuda-pp acpp-pcuda-pp.cpp)

target_compile_definitions(acpp-pcuda-pp PRIVATE -DHIPSYCL_TOOL_COMPONENT)
target_include_directories(acpp-pcuda-pp PRIVATE 
    ${HIPSYCL_SOURCE_DIR}
    ${HIPSYCL_SOURCE_DIR}/include
    ${PROJECT_BINARY_DIR}/include)

# Same rpath idiom as the other tools: anything of ours this tool links
# resolves relative to the installed binary, never through a build-machine
# link path.
set_target_properties(acpp-pcuda-pp PROPERTIES INSTALL_RPATH ${base}/../lib/)

install(TARGETS acpp-pcuda-pp DESTINATION bin)
