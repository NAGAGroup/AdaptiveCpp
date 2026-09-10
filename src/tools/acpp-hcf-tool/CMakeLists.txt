add_executable(acpp-hcf-tool acpp-hcf-tool.cpp)
target_compile_definitions(acpp-hcf-tool PRIVATE -DHIPSYCL_TOOL_COMPONENT)
target_include_directories(acpp-hcf-tool PRIVATE 
    ${HIPSYCL_SOURCE_DIR}
    ${HIPSYCL_SOURCE_DIR}/include
    ${ACPP_BINARY_ROOT}/include)

# Same rpath idiom as the other tools: anything of ours this tool links
# resolves relative to the installed binary, never through a build-machine
# link path.
set_target_properties(acpp-hcf-tool PROPERTIES INSTALL_RPATH ${base}/../lib/)

install(TARGETS acpp-hcf-tool DESTINATION bin)
