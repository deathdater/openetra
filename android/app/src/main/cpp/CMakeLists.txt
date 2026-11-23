cmake_minimum_required(VERSION 3.22.1)
project(openetra_mirage LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CACTUS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/cactus")
set(CACTUS_STATIC_LIB "${CACTUS_ROOT}/${ANDROID_ABI}/libcactus.a")

if(NOT EXISTS "${CACTUS_STATIC_LIB}")
    message(FATAL_ERROR "Missing pinned libcactus.a for ABI ${ANDROID_ABI} at ${CACTUS_STATIC_LIB}")
endif()

add_library(cactus_runtime STATIC IMPORTED)
set_target_properties(cactus_runtime PROPERTIES
    IMPORTED_LOCATION "${CACTUS_STATIC_LIB}"
)

add_library(openetra_mirage SHARED
    openetra_mirage_jni.cpp
)

target_include_directories(openetra_mirage PRIVATE
    "${CACTUS_ROOT}/include"
)

target_compile_options(openetra_mirage PRIVATE
    -O2
    -Wall
    -Wextra
)

target_link_options(openetra_mirage PRIVATE
    -Wl,-z,max-page-size=16384
)

target_link_libraries(openetra_mirage PRIVATE
    cactus_runtime
    log
    android
    m
    dl
)
