# C bridge for the embedded backend. Ada is built through Alire.
idf_component_register(
    SRCS "source/embedded/ada-espidf.c"
         "source/embedded/ada-freertos.c"
         "source/embedded/ada-unwind.c"
    PRIV_REQUIRES freertos)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/embedded-unwind.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/system-os_constants.cmake")
