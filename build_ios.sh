#!/bin/bash
set -ex

# Set variables
SRC_DIR=$(dirname $0)
OUTPUT_DIR="$(pwd)/output"
readonly DEVELOPER=$(xcode-select --print-path)
readonly PLATFORMSROOT="${DEVELOPER}/Platforms"

aclocal && autoconf && automake --add-missing

# Create output directory
mkdir -p "$OUTPUT_DIR"

config_library() {
    local platform=$1
    local arch=$2
    local sdk=$3
    
    ROOTDIR="${OUTPUT_DIR}/${platform}-${arch}-${sdk}"
    mkdir -p "${ROOTDIR}"

    SDKROOT="${PLATFORMSROOT}/"
    SDKROOT+="${sdk}.platform/Developer/SDKs/${sdk}.sdk/"
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
    
    ${SRC_DIR}/configure --host=${arch}-apple-darwin --prefix=${ROOTDIR} \
    --build=$(${SRC_DIR}/config.guess) \
    --disable-shared --enable-static \
    CXX="${CXX} -arch ${ARCH2:-${arch}} " \
    CFLAGS="${CFLAGS}" \
	  CXXFLAGS="${CFLAGS} -isystem ${SDKROOT}/usr/include"
}

# Function to build for a specific platform and architecture
build_library() {
    local platform=$1
    local arch=$2
    local sdk=$3
    local out_dir="$OUTPUT_DIR/$platform-$arch-$sdk"

    mkdir -p "$out_dir"

    config_library $platform $arch $sdk
  
    make -j4 V=0
    make install
    make clean
}

create_xcframework() {
    local lib_name=$1

    lipo -create "$OUTPUT_DIR/iphonesimulator-x86_64-iPhoneSimulator/lib/lib$lib_name.a" \
      "$OUTPUT_DIR/iphonesimulator-arm64-iPhoneSimulator/lib/lib$lib_name.a" \
      -output "$OUTPUT_DIR/iphonesimulator-lib$lib_name.a"
    
    lipo -create "$OUTPUT_DIR/macosx-x86_64-MacOSX/lib/lib$lib_name.a" \
      "$OUTPUT_DIR/macosx-arm64-MacOSX/lib/lib$lib_name.a" \
      -output "$OUTPUT_DIR/macosx-lib$lib_name.a"

    xcodebuild -create-xcframework \
    -library "$OUTPUT_DIR/iphoneos-arm64-iPhoneOS/lib/lib$lib_name.a" \
    -headers "$OUTPUT_DIR/Headers/" \
    -library "$OUTPUT_DIR/iphonesimulator-lib$lib_name.a" \
    -headers "$OUTPUT_DIR/Headers/" \
    -library "$OUTPUT_DIR/macosx-lib$lib_name.a" \
    -headers "$OUTPUT_DIR/Headers/" \
    -output "$OUTPUT_DIR/$lib_name.xcframework"
}

# Build for different platforms and architectures
build_library "macosx" "arm64" "MacOSX"
build_library "macosx" "x86_64" "MacOSX"
build_library "iphoneos" "arm64" "iPhoneOS"
build_library "iphonesimulator" "x86_64" "iPhoneSimulator"
build_library "iphonesimulator" "arm64" "iPhoneSimulator"


# Create XCFramework
mkdir -p "${OUTPUT_DIR}/Headers/"

rm -rf ${OUTPUT_DIR}/Headers/*
rm -rf ${OUTPUT_DIR}/opencore-amrnb.xcframework
cp -a ${SRC_DIR}/amrnb/{interf_dec,interf_enc}.h ${OUTPUT_DIR}/Headers/
create_xcframework "opencore-amrnb"

rm -rf ${OUTPUT_DIR}/Headers/*
rm -rf ${OUTPUT_DIR}/opencore-amrwb.xcframework
cp -a ${SRC_DIR}/amrwb/{dec_if,if_rom}.h ${OUTPUT_DIR}/Headers/
create_xcframework "opencore-amrwb"

echo "Universal XCFramework built successfully in $OUTPUT_DIR"
