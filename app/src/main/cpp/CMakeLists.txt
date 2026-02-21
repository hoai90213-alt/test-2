cmake_minimum_required(VERSION 3.13)
project(zomdroid)
cmake_policy(SET CMP0079 NEW)
set(CMAKE_C_STANDARD 11)

option(ZOMDROID_BUILD_GLFW "Build bundled GLFW target" ON)
option(ZOMDROID_BUILD_LINKER "Build zomdroid linker/emulation target" ON)
set(ZOMDROID_BUILD_ANDROID_JNI ${ANDROID} CACHE BOOL "Build Android JNI entrypoint")

#add_subdirectory(gl4es)
#set_target_properties(GL PROPERTIES
#        LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} # originally ${CMAKE_SOURCE_DIR}/lib
#        SUFFIX .so # originally so.1
#        #OUTPUT_NAME gl4es
#)
##target_compile_definitions(GL PRIVATE DEBUG)
#target_compile_definitions(GL PRIVATE NOX11)
#target_compile_definitions(GL PRIVATE NO_GBM)
#target_compile_definitions(GL PRIVATE NOEGL) # EGL context creation is handled by glfw

set(GLFW_BUILD_WAYLAND OFF CACHE BOOL "Disable Wayland support" FORCE)
set(GLFW_BUILD_X11 OFF CACHE BOOL "Disable X11 support" FORCE)
set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libs" FORCE)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "Build docs" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "Install" FORCE)
if(ZOMDROID_BUILD_GLFW)
    set(GLFW_BUILD_ZOMDROID ON)
    add_subdirectory(glfw)
    set_target_properties(glfw PROPERTIES
            LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} # originally ${CMAKE_SOURCE_DIR}/lib
    )
    target_include_directories(glfw PRIVATE .)
    if(ANDROID)
        target_link_libraries(glfw PRIVATE log zomdroid EGL nativewindow)
    else()
        target_link_libraries(glfw PRIVATE zomdroid)
    endif()
endif()

if(ANDROID)
    add_subdirectory(liblinkernsbypass)
endif()

set(ZOMDROID_CORE_SOURCES
        zomdroid.c)
if(ZOMDROID_BUILD_ANDROID_JNI)
    list(APPEND ZOMDROID_CORE_SOURCES zomdroid_jni.c)
endif()
add_library(zomdroid SHARED ${ZOMDROID_CORE_SOURCES})
if(ANDROID)
    target_link_libraries(zomdroid log android linkernsbypass)
elseif(APPLE)
    target_link_libraries(zomdroid)
else()
    target_link_libraries(zomdroid dl pthread)
endif()

if(ZOMDROID_BUILD_LINKER)
    add_library(zomdroidlinker SHARED linker.c emulation.c wrapped_jni.c)
    if(ANDROID)
        target_link_libraries(zomdroidlinker PRIVATE c log box64 zomdroid) # link to libc before box64 to prevent mmap override
        target_link_options(zomdroidlinker PRIVATE "-Wl,-z,global")
    elseif(APPLE)
        target_link_libraries(zomdroidlinker PRIVATE box64 zomdroid)
    else()
        target_link_libraries(zomdroidlinker PRIVATE c dl box64 zomdroid)
    endif()

    set(NOGIT ON)
    if(APPLE)
        set(ARM_DYNAREC OFF CACHE BOOL "Disable dynarec for iOS runtime probe builds" FORCE)
        set(ARM64 ON CACHE BOOL "Build box64 for generic ARM64 target" FORCE)
    else()
        set(ARM_DYNAREC ON CACHE BOOL "Enable dynarec on non-Apple targets" FORCE)
    endif()
    add_subdirectory(box64)
    target_compile_definitions(box64 PRIVATE BUILD_DYNAMIC)
endif()
