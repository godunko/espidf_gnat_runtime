if(NOT CONFIG_LIBC_NEWLIB)
    message(WARNING "`espidf_gnat_runtime` requires CONFIG_LIBC_NEWLIB=y. Configure Newlib in menuconfig under Component config -> LibC. Build will fail until then.")
endif()

idf_component_register(REQUIRES cxx freertos)
target_linker_script(${COMPONENT_LIB} INTERFACE "${CMAKE_CURRENT_LIST_DIR}/discard_gpr_linker_options.ld")

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

# Remove generated runtime artifacts on clean.
set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES
    "${COMPONENT_DIR}/runtime")

if(NOT CONFIG_LIBC_NEWLIB)
    add_custom_target(espidf_gnat_runtime_newlib_check ALL
        COMMAND ${CMAKE_COMMAND} -E echo "ERROR: \`espidf_gnat_runtime\` requires CONFIG_LIBC_NEWLIB=y. Select Newlib under Component config -> LibC."
        COMMAND ${CMAKE_COMMAND} -E false
        VERBATIM)
    add_dependencies(espidf_gnat_runtime_build espidf_gnat_runtime_newlib_check)
endif()

add_dependencies(espidf_gnat_runtime espidf_gnat_runtime_build)
