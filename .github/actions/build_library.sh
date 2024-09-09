#!/bin/bash
set -ex

platform=$1
arch=$2
sdk=$3
OUTPUT_DIR="${GITHUB_WORKSPACE}/output"
DEVELOPER=$(xcode-select --print-path)
PLATFORMSROOT="${DEVELOPER}/Platforms"

config_library() {
    ROOTDIR="${OUTPUT_DIR}/${platform}-${arch}-${sdk}"
    mkdir -p "${ROOTDIR}"

    SDKROOT="${PLATFORMSROOT}/${sdk}.platform/Developer/SDKs/${sdk}.sdk/"
    CFLAGS="-arch ${ARCH2:-${arch}} -pipe -isysroot ${SDKROOT} -O3 -DNDEBUG"

    if [[ ${platform} == "iphoneos" ]]; then
        CFLAGS+=" -miphoneos-version-min=7.0 ${EXTRA_CFLAGS}"
    fi
    if [[ ${platform} == "iphonesimulator" ]]; then
        CFLAGS+=" -mios-simulator-version-min=7.0 ${EXTRA_CFLAGS}"
    fi
    if [[ ${platform} == "macosx" ]]; then
        CFLAGS+=" -mmacosx-version-min=10.9 ${EXTRA_CFLAGS}"
    fi

    CXX="xcrun --sdk ${platform} clang++ "
    
    ./configure --host=${arch}-apple-darwin --prefix=${ROOTDIR} \
    --build=$(./config.guess) \
    --disable-shared --enable-static \
    CXX="${CXX} -arch ${ARCH2:-${arch}} " \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CFLAGS} -isystem ${SDKROOT}/usr/include"
}

config_library

make -j4 V=0
make install
make clean
