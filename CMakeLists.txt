# C bridge for the embedded backend. Ada is built through Alire.
idf_component_register(
    SRCS "source/embedded/embedded.c"
         "source/embedded/ada-unwind.c"
    PRIV_REQUIRES freertos)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/embedded-unwind.cmake")
