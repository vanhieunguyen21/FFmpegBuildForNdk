cmake_minimum_required(VERSION 3.18.1)

project("nativeapp")

link_directories(${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
include_directories(${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include)

# SET DIRECTORIES SECTION: END

include(ExternalProject)

set(FFMPEG_LIBS avutil swresample avcodec avformat swscale avfilter avdevice)

# ANDROID BUILD TOOLS SECTION: START

set(TOOLCHAIN_ROOT ${ANDROID_TOOLCHAIN_ROOT})
string(REPLACE "\\" "/" TOOLCHAIN_ROOT ${TOOLCHAIN_ROOT})

set(LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
string(REPLACE "\\" "/" LIBRARY_OUTPUT_DIRECTORY ${LIBRARY_OUTPUT_DIRECTORY})

set(CURRENT_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
string(REPLACE "\\" "/" CURRENT_SOURCE_DIR ${CURRENT_SOURCE_DIR})

set(SYSROOT ${CMAKE_SYSROOT})
string(REPLACE "\\" "/" SYSROOT ${SYSROOT})

set(CC ${CMAKE_C_COMPILER})
string(REPLACE "\\" "/" CC ${CC})

set(CXX ${CMAKE_CXX_COMPILER})
string(REPLACE "\\" "/" CXX ${CXX})

set(AR ${ANDROID_AR})
string(REPLACE "\\" "/" AR ${AR})

set(AS ${ANDROID_ASM_COMPILER})
string(REPLACE "\\" "/" AS ${AS})

set(NM ${TOOLCHAIN_ROOT}/bin/llvm-nm.exe)
string(REPLACE "\\" "/" NM ${NM})

set(STRIP ${TOOLCHAIN_ROOT}/bin/llvm-strip.exe)
string(REPLACE "\\" "/" STRIP ${STRIP})

set(RANLIB ${CMAKE_RANLIB})
string(REPLACE "\\" "/" RANLIB ${RANLIB})

set(BUILD_PATH "${CURRENT_SOURCE_DIR}/output/")
set(BUILD_PREFIX "${BUILD_PATH}/${CMAKE_ANDROID_ARCH_ABI}")

# ANDROID BUILD TOOLS SECTION: END

include(libx264.cmake)
include(ffmpeg.cmake)

# BUILD ALL SCRIPT SECTION: START

file(WRITE ${CURRENT_SOURCE_DIR}/build_all.sh
"#!/bin/bash
echo \"Building all\"

echo \"Removing old build\"
rm -rf ${BUILD_PATH}

echo \"Building libx264\"
bash /${LIBX264_NAME}/build_all.sh
echo \"Libx264 building done\"

echo \"Building FFmpeg\"
bash /${FFMPEG_NAME}/build_all.sh
echo \"FFmpeg building done\"
")

# BUILD ALL SCRIPT SECTION: END

add_library(nativeapp SHARED native-lib.cpp)

find_library(log-lib log)

target_link_libraries(nativeapp ${log-lib})