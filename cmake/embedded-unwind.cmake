# Keep SDK FDE code/ABI, replacing only its two blocking mutex references.
# The installed compiler and libgcc archive remain read only.
execute_process(COMMAND ${CMAKE_C_COMPILER} -print-libgcc-file-name
    OUTPUT_VARIABLE _sdk_libgcc OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
set(_fde "${CMAKE_CURRENT_BINARY_DIR}/embedded-unwind-dw2-fde.o")
execute_process(COMMAND ${CMAKE_AR} p ${_sdk_libgcc} unwind-dw2-fde.o
    OUTPUT_FILE ${_fde} COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${CMAKE_NM} --undefined-only ${_fde}
    OUTPUT_VARIABLE _fde_refs COMMAND_ERROR_IS_FATAL ANY)
foreach(_binding pthread_mutex_lock pthread_mutex_unlock pthread_cancel)
    if(NOT _fde_refs MATCHES "${_binding}")
        message(FATAL_ERROR "Inspect unwinder synchronization in ${_sdk_libgcc}: missing ${_binding}")
    endif()
endforeach()
message(STATUS "Embedded ISR unwinder: adapting mutex references from ${_sdk_libgcc}")
execute_process(COMMAND ${CMAKE_OBJCOPY}
    --redefine-sym pthread_mutex_lock=__gnat_unwind_lock
    --redefine-sym pthread_mutex_unlock=__gnat_unwind_unlock
    --redefine-sym pthread_cancel=__gnat_unwind_active
    ${_fde} COMMAND_ERROR_IS_FATAL ANY)
# An explicit object before libgcc prevents extraction of its original FDE member.
# Weak gthread references do not extract ada-unwind.c from the component archive.
# Force all three bindings into the link and retain their sections with --gc-sections.
target_link_options(${COMPONENT_LIB} INTERFACE
    "-Wl,--undefined=__gnat_unwind_active"
    "-Wl,--undefined=__gnat_unwind_lock"
    "-Wl,--undefined=__gnat_unwind_unlock"
    ${_fde})
execute_process(COMMAND ${CMAKE_NM} --undefined-only ${_fde}
    OUTPUT_VARIABLE _adapted_refs COMMAND_ERROR_IS_FATAL ANY)
if(_adapted_refs MATCHES "pthread_")
    message(FATAL_ERROR "Inspect additional unwinder pthread dependencies: ${_adapted_refs}")
endif()
