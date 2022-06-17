cmake_minimum_required(VERSION 3.18.1)

# LIBX264 FETCH SECTION: START

set(LIBX264_URL https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2)
get_filename_component(LIBX264_ARCHIVE_NAME ${LIBX264_URL} NAME)
get_filename_component(LIBX264_NAME ${LIBX264_URL} NAME_WE)

IF (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_NAME})
    file(DOWNLOAD ${LIBX264_URL} ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_ARCHIVE_NAME})
    execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_ARCHIVE_NAME}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    # We're patching install step manually because it installs libx264 with version suffix and Android won't have it
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_NAME}/configure configure_src)
    string(REPLACE "echo \"SONAME=libx264.so.$API\" >> config.mak" "echo \"SONAME=libx264.so\" >> config.mak" configure_src "${configure_src}")
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_NAME}/configure "${configure_src}")

    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_NAME}/Makefile makefile_src)
    string(REPLACE "ln -f -s $(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)"
            "# ln -f -s $(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)" makefile_src "${makefile_src}")
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/${LIBX264_NAME}/Makefile "${makefile_src}")
ENDIF ()

# LIBX264 FETCH SECTION: END

# ANDROID FLAGS SECTION: START
string(REPLACE " -Wl,--fatal-warnings" "" LIBX264_LD_FLAGS ${CMAKE_SHARED_LINKER_FLAGS})

string(STRIP ${CMAKE_C_FLAGS} LIBX264_C_FLAGS)
string(STRIP ${LIBX264_LD_FLAGS} LIBX264_LD_FLAGS)

set(LIBX264_C_FLAGS "${LIBX264_C_FLAGS} --target=${ANDROID_LLVM_TRIPLE} --gcc-toolchain=${ANDROID_TOOLCHAIN_ROOT}")
set(LIBX264_ASM_FLAGS "${CMAKE_ASM_FLAGS} --target=${ANDROID_LLVM_TRIPLE}")
set(LIBX264_LD_FLAGS "${LIBX264_C_FLAGS} ${LIBX264_LD_FLAGS}")

# ANDROID FLAGS SECTION: END

# MISC VARIABLES SECTION: START

set(NJOBS 4)
set(HOST_BIN ${ANDROID_NDK}/prebuilt/${ANDROID_HOST_TAG}/bin)
string(REPLACE "\\" "/" HOST_BIN ${HOST_BIN})

# MISC VARIABLES SECTION: END

# CONFIGURATION FLAGS SECTION: START

set(LIBX264_CONFIGURE_EXTRAS "")
IF (${CMAKE_ANDROID_ARCH_ABI} MATCHES ^x86)
    # We use NASM since YASM is severely outdated and libx264 won't compile with it
    find_program(NASM_EXE nasm)

    IF (NASM_EXE)
        SET(LIBX264_AS ${NASM_EXE})
        SET(LIBX264_ASM_FLAGS "") # We don't set any flags since those are set in libx264 configure
    ENDIF()

    # We explicitly disable assembler on x86 because of -mstackrealign causing inline assembly
    # to take up too many registers on API < 24
    IF(NOT NASM_EXE OR ${CMAKE_ANDROID_ARCH_ABI} STREQUAL x86)
        list(APPEND LIBX264_CONFIGURE_EXTRAS --disable-asm) # no nasm, disable assembler for x86
    ENDIF()
    IF(NOT NASM_EXE OR ${CMAKE_ANDROID_ARCH_ABI} STREQUAL x86_64)
        list(APPEND LIBX264_CONFIGURE_EXTRAS --disable-asm) # no nasm, disable x86 assembler for x86_64
    ENDIF()
ENDIF()

string(REPLACE ";" " " LIBX264_CONFIGURE_EXTRAS_ENCODED "${LIBX264_CONFIGURE_EXTRAS}")

# CONFIGURATION FLAGS SECTION: END

# LIBX264 EXTERNAL PROJECT CONFIG SECTION: START

set(
        CONFIGURE_COMMAND
        "${CURRENT_SOURCE_DIR}/${LIBX264_NAME}/configure
        --sysroot=${SYSROOT}
        --host=${ANDROID_LLVM_TRIPLE}
        --libdir=${BUILD_PREFIX}
        --prefix=${BUILD_PREFIX}

        --extra-cflags=\"${LIBX264_C_FLAGS}\"
        --extra-ldflags=\"${LIBX264_LD_FLAGS}\"
        --extra-asflags=\"${LIBX264_ASM_FLAGS}\"

        --enable-pic
        --enable-shared
        --disable-cli
        ${LIBX264_CONFIGURE_EXTRAS_ENCODED}"
)

string(REGEX REPLACE "[ \t\r\n]+" " " CONFIGURE_COMMAND ${CONFIGURE_COMMAND})

file(WRITE ${CURRENT_SOURCE_DIR}/${LIBX264_NAME}/build_${CMAKE_SYSTEM_PROCESSOR}.sh

"#!/bin/bash
echo \"Configuring libx264\"

export HOST_TAG=windows_x86-64
export CC=${CC}
export AS=${AS}
export AR=${AR}
export RANLIB=${RANLIB}
export STRIP=${STRIP}

${CONFIGURE_COMMAND}

echo \"Configuration done\"

make clean
make -j${NJOBS}
make install
")

file(WRITE ${CURRENT_SOURCE_DIR}/${LIBX264_NAME}/build_all.sh

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

# LIBX264 EXTERNAL PROJECT CONFIG SECTION: END