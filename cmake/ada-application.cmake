include_guard(GLOBAL)
include(ExternalProject)

# Build an Alire application producing a relocatable object for the IDF link.
# Relative PROJECT_DIR paths are resolved against the caller's source directory;
# relative OBJECT paths are resolved against PROJECT_DIR.
function(espidf_add_ada_application)
    cmake_parse_arguments(ADA "" "TARGET;PROJECT_DIR;OBJECT" "" ${ARGN})
    if(ADA_UNPARSED_ARGUMENTS OR ADA_KEYWORDS_MISSING_VALUES OR
       NOT ADA_TARGET OR NOT ADA_PROJECT_DIR OR NOT ADA_OBJECT)
        message(FATAL_ERROR
            "espidf_add_ada_application requires TARGET, PROJECT_DIR and OBJECT")
    endif()
    if(NOT TARGET "${ADA_TARGET}")
        message(FATAL_ERROR "Unknown Ada application target: ${ADA_TARGET}")
    endif()

    get_filename_component(_project_dir "${ADA_PROJECT_DIR}" ABSOLUTE
        BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    get_filename_component(_object "${ADA_OBJECT}" ABSOLUTE
        BASE_DIR "${_project_dir}")

    set(_build_target "${ADA_TARGET}_ada_build")
    ExternalProject_Add("${_build_target}"
        DEPENDS gnat_system_os_constants
        PREFIX "${CMAKE_CURRENT_BINARY_DIR}/ada/${_build_target}"
        SOURCE_DIR "${_project_dir}"
        BUILD_IN_SOURCE 1
        BUILD_ALWAYS 1
        DOWNLOAD_COMMAND ""
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND "${CMAKE_COMMAND}" -E chdir "${_project_dir}" alr -n build
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS "${_object}")

    # IDF can represent a component with no C sources as an INTERFACE library.
    # Its build dependency is followed by consumers, including the firmware ELF.
    add_dependencies("${ADA_TARGET}" "${_build_target}")
    target_link_libraries("${ADA_TARGET}" INTERFACE "${_object}")
endfunction()
