if(CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT LESS 1 OR
   NOT CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT LESS CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS)
    message(FATAL_ERROR
        "GNAT runtime TLS slot ${CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT} is outside "
        "the usable range: slot 0 is reserved for pthread, and "
        "CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS=${CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS}. "
        "Increase the FreeRTOS TLS pointer count or choose a smaller GNAT runtime TLS slot.")
endif()

# Compile the probe with the component's options and target headers.
add_library(gnat_system_os_constants_probe OBJECT "tools/system_os_constants.c")
foreach(_property COMPILE_OPTIONS COMPILE_DEFINITIONS INCLUDE_DIRECTORIES)
    set_property(TARGET gnat_system_os_constants_probe PROPERTY ${_property}
        "$<TARGET_PROPERTY:${COMPONENT_LIB},${_property}>")
endforeach()
target_link_libraries(gnat_system_os_constants_probe PRIVATE idf::freertos)

set(_system_os_constants "${COMPONENT_DIR}/.gens/s-oscons.ads")
add_custom_command(OUTPUT "${_system_os_constants}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${COMPONENT_DIR}/.gens"
    COMMAND "${PYTHON}" "${COMPONENT_DIR}/tools/system_os_constants.py"
        --nm "${CMAKE_NM}" --output "${_system_os_constants}"
        $<TARGET_OBJECTS:gnat_system_os_constants_probe>
    DEPENDS gnat_system_os_constants_probe
        $<TARGET_OBJECTS:gnat_system_os_constants_probe>
        "${COMPONENT_DIR}/tools/system_os_constants.py"
    COMMAND_EXPAND_LISTS VERBATIM)
add_custom_target(gnat_system_os_constants DEPENDS "${_system_os_constants}")
add_dependencies(${COMPONENT_LIB} gnat_system_os_constants)
