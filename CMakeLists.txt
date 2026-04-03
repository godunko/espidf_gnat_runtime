idf_component_register(REQUIRES cxx freertos)

ExternalProject_Add(espidf_gnat_runtime
    PREFIX ${COMPONENT_DIR}
    SOURCE_DIR ${COMPONENT_DIR}
    BUILD_IN_SOURCE 1
    BUILD_ALWAYS 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND alr build -- -cargs:c
        "-D$<JOIN:$<TARGET_PROPERTY:espidf_gnat_runtime_build,INTERFACE_COMPILE_DEFINITIONS>,$<SEMICOLON>-D>"
        "-I$<JOIN:$<TARGET_PROPERTY:espidf_gnat_runtime_build,INTERFACE_INCLUDE_DIRECTORIES>,$<SEMICOLON>-I>"
    COMMAND_EXPAND_LISTS
    VERBATIM
    INSTALL_COMMAND ""
    BUILD_BYPRODUCTS ${COMPONENT_DIR}/runtime/lib/libgnat.a ${COMPONENT_DIR}/runtime/lib/libgnarl.a
)

add_prebuilt_library(espidf_gnat_runtime_build "${COMPONENT_LIB}"
    REQUIRES cxx freertos)
add_dependencies(espidf_gnat_runtime espidf_gnat_runtime_build)
