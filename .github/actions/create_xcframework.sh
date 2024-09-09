#!/bin/bash
set -ex

lib_name=$1
OUTPUT_DIR="${GITHUB_WORKSPACE}/output"

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
