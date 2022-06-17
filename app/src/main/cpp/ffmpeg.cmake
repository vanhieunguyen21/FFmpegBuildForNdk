cmake_minimum_required(VERSION 3.18.1)

# FFMPEG FETCH SECTION: START

set(FFMPEG_VERSION 5.0.1)
set(FFMPEG_NAME ffmpeg-${FFMPEG_VERSION})
set(FFMPEG_URL https://ffmpeg.org/releases/${FFMPEG_NAME}.tar.bz2)

get_filename_component(FFMPEG_ARCHIVE_NAME ${FFMPEG_URL} NAME)

IF (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_NAME})
    file(DOWNLOAD ${FFMPEG_URL} ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_ARCHIVE_NAME})

    execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_ARCHIVE_NAME}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    # We're patching exit just before return in main function of ffmpeg.c because it will crash the application
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_NAME}/fftools/ffmpeg.c ffmpeg_src)

    string(REPLACE "exit_program(received_nb_signals ? 255 : main_return_code);" "//exit_program(received_nb_signals ? 255 : main_return_code);" ffmpeg_src "${ffmpeg_src}")
    string(REPLACE "return main_return_code;" "return received_nb_signals ? 255 : main_return_code;" ffmpeg_src "${ffmpeg_src}")

    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_NAME}/fftools/ffmpeg.c "${ffmpeg_src}")
ENDIF ()

#file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg_build_system.cmake
#        DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/${FFMPEG_NAME}
#        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# FFMPEG FETCH SECTION: END

# ANDROID FLAGS SECTION: START

# libx264 support
set(FFMPEG_EXTRA_C_FLAGS "-I${BUILD_PREFIX}/include")
set(FFMPEG_EXTRA_LD_FLAGS "-L${BUILD_PREFIX}")


# We remove --fatal-warnings in such blatant way because somebody at Google decided it's an excellent idea
# to put it into LD flags in toolchain without any way to turn it off.
string(REPLACE " -Wl,--fatal-warnings" "" FFMPEG_LD_FLAGS ${CMAKE_SHARED_LINKER_FLAGS})

set(FFMPEG_C_FLAGS "${CMAKE_C_FLAGS} --target=${ANDROID_LLVM_TRIPLE} --gcc-toolchain=${ANDROID_TOOLCHAIN_ROOT} ${FFMPEG_EXTRA_C_FLAGS}")
set(FFMPEG_ASM_FLAGS "${CMAKE_ASM_FLAGS} --target=${ANDROID_LLVM_TRIPLE} ${FFMPEG_EXTRA_ASM_FLAGS}")
set(FFMPEG_LD_FLAGS "${FFMPEG_C_FLAGS} ${FFMPEG_LD_FLAGS} ${FFMPEG_EXTRA_LD_FLAGS}")

# ANDROID FLAGS SECTION: END

# MISC VARIABLES SECTION: START

set(NJOBS 4)
set(HOST_BIN ${ANDROID_NDK}/prebuilt/${ANDROID_HOST_TAG}/bin)
string(REPLACE "\\" "/" HOST_BIN ${HOST_BIN})

# MISC VARIABLES SECTION: END

# FFMPEG EXTERNAL PROJECT CONFIG SECTION: START

set(FFMPEG_CONFIGURE_EXTRAS --enable-jni --enable-mediacodec)
# https://trac.ffmpeg.org/ticket/4928 we must disable asm for x86 since it's non-PIC by design from FFmpeg side
IF (${CMAKE_ANDROID_ARCH_ABI} STREQUAL x86)
    list(APPEND FFMPEG_CONFIGURE_EXTRAS --disable-asm)
ENDIF ()
IF (${CMAKE_ANDROID_ARCH_ABI} STREQUAL x86_64)
    list(APPEND FFMPEG_CONFIGURE_EXTRAS --disable-x86asm)
ENDIF ()

string(REPLACE ";" " " FFMPEG_CONFIGURE_EXTRAS_ENCODED "${FFMPEG_CONFIGURE_EXTRAS}")

set(
        CONFIGURE_COMMAND
        "${CURRENT_SOURCE_DIR}/${FFMPEG_NAME}/configure
        --cc=${CC}
        --ar=${AR}
        --strip=${STRIP}
        --ranlib=${RANLIB}
        --as=${AS}
        --nm=${NM}
        --target-os=android
        --arch=${CMAKE_SYSTEM_PROCESSOR}
        --extra-cflags=\"${FFMPEG_C_FLAGS}\"
        --extra-ldflags=\"${FFMPEG_LD_FLAGS}\"
        --sysroot=${SYSROOT}
        --shlibdir=${BUILD_PREFIX}
        --prefix=${BUILD_PREFIX}

        --enable-cross-compile
        --disable-static
        --disable-programs
        --disable-doc
        --enable-pic
        --enable-shared
        --enable-gpl

        --disable-avdevice
        --disable-postproc
        --disable-avfilter
        --disable-everything

        --enable-protocol=file
        --enable-protocol=rtp
        --enable-libx264

        --enable-encoder=libx264
        --enable-encoder=aac
        --enable-encoder=mpeg4
        --enable-encoder=pcm_s16le
        --enable-encoder=yuv4

        --enable-decoder=aac
        --enable-decoder=h263
        --enable-decoder=h264
        --enable-decoder=mpeg4
        --enable-decoder=pcm_s16le
        --enable-decoder=yuv4

        --enable-parser=aac
        --enable-parser=h263
        --enable-parser=h264
        --enable-parser=mpeg4video
        --enable-parser=mpegaudio
        --enable-parser=mpegvideo

        --enable-muxer=mp4

        --enable-demuxer=mov
        --enable-demuxer=h263
        --enable-demuxer=h264
        --enable-demuxer=rtsp

        ${FFMPEG_CONFIGURE_EXTRAS_ENCODED}"
)
string(REGEX REPLACE "[ \t\r\n]+" " " CONFIGURE_COMMAND ${CONFIGURE_COMMAND})

file(WRITE ${CURRENT_SOURCE_DIR}/${FFMPEG_NAME}/build_${CMAKE_SYSTEM_PROCESSOR}.sh

"#!/bin/bash
echo \"Configuring ${CMAKE_SYSTEM_PROCESSOR}\"

${CONFIGURE_COMMAND}

echo \"Configuration done\"

make clean
make -j${NJOBS}
make install
")

file(WRITE ${CURRENT_SOURCE_DIR}/${FFMPEG_NAME}/build_all.sh

"#!/bin/bash
my_scriptname=\"$(basename $0)\"
for f in *.sh; do
    if [ \"$my_scriptname\" != \"$f\" ]; then
        echo \"Starting $f\"
        bash \"$f\"
        echo \"Finished $f\"
    fi
done
")