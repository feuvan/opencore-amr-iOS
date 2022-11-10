#!/bin/bash
### more reference https://chromium.googlesource.com/webm/libwebp/+/refs/heads/master/iosbuild.sh
set -e

# Extract the latest SDK version from the final field of the form: iphoneosX.Y
readonly SDK=$(xcodebuild -showsdks \
  | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF, 9)}'
)
# Extract Xcode version.
readonly XCODE=$(xcodebuild -version | grep Xcode | cut -d " " -f2)
if [[ -z "${XCODE}" ]]; then
  echo "Xcode not available"
  exit 1
fi
readonly OLDPATH=${PATH}
# Add iPhoneOS-V6 to the list of platforms below if you need armv6 support.
# Note that iPhoneOS-V6 support is not available with the iOS6 SDK.
PLATFORMS="iPhoneSimulator iPhoneSimulator64"
PLATFORMS+=" iPhoneOS-V7 iPhoneOS-V7s iPhoneOS-V7-arm64"
readonly PLATFORMS
readonly SRCDIR=$(dirname $0)
readonly TOPDIR=$(pwd)
readonly BUILDDIR="${TOPDIR}/iosbuild"
readonly AMRNBTARGETDIR="${TOPDIR}/opencore-amrnb.framework"
readonly AMRWBTARGETDIR="${TOPDIR}/opencore-amrwb.framework"
readonly DEVELOPER=$(xcode-select --print-path)
readonly PLATFORMSROOT="${DEVELOPER}/Platforms"
readonly LIPO=$(xcrun -sdk iphoneos${SDK} -find lipo)
AMRNBLIBLIST=''
AMRWBLIBLIST=''

if [[ -z "${SDK}" ]]; then
  echo "iOS SDK not available"
  exit 1
elif [[ ${SDK%%.*} -gt 8 ]]; then
  EXTRA_CFLAGS="-fembed-bitcode"
elif [[ ${SDK} < 7.0 ]]; then
  echo "You need iOS SDK version 7.0 or above"
  exit 1
else
  echo "iOS SDK Version ${SDK}"
fi

rm -rf ${BUILDDIR} ${AMRNBTARGETDIR} ${AMRWBTARGETDIR}
mkdir -p ${BUILDDIR} ${AMRNBTARGETDIR}/Headers/ ${AMRWBTARGETDIR}/Headers/

make clean
for PLATFORM in ${PLATFORMS}; do
  ARCH2=""
  CXX="xcrun --sdk iphoneos clang++  "
  if [[ "${PLATFORM}" == "iPhoneOS-V7-arm64" ]]; then
    PLATFORM="iPhoneOS"
    ARCH="aarch64"
    ARCH2="arm64"
  elif [[ "${PLATFORM}" == "iPhoneOS-V7s" ]]; then
    PLATFORM="iPhoneOS"
    ARCH="armv7s"
  elif [[ "${PLATFORM}" == "iPhoneOS-V7" ]]; then
    PLATFORM="iPhoneOS"
    ARCH="armv7"
  elif [[ "${PLATFORM}" == "iPhoneOS-V6" ]]; then
    PLATFORM="iPhoneOS"
    ARCH="armv6"
  elif [[ "${PLATFORM}" == "iPhoneSimulator64" ]]; then
    PLATFORM="iPhoneSimulator"
    ARCH="x86_64"
	CXX="xcrun --sdk iphonesimulator clang++ "
  else
    ARCH="i386"
	CXX="xcrun --sdk iphonesimulator clang++ "
  fi
  ROOTDIR="${BUILDDIR}/${PLATFORM}-${SDK}-${ARCH}"
  mkdir -p "${ROOTDIR}"
  DEVROOT="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"
  SDKROOT="${PLATFORMSROOT}/"
  SDKROOT+="${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDK}.sdk/"
  CFLAGS="-arch ${ARCH2:-${ARCH}} -pipe -isysroot ${SDKROOT} -O3 -DNDEBUG"
  CFLAGS+=" -miphoneos-version-min=7.0 ${EXTRA_CFLAGS}"
  set -x
  export PATH="${DEVROOT}/usr/bin:${OLDPATH}"
  ${SRCDIR}/configure --host=${ARCH}-apple-darwin --prefix=${ROOTDIR} \
    --build=$(${SRCDIR}/config.guess) \
    --disable-shared --enable-static \
	CXX="${CXX} -arch ${ARCH2:-${ARCH}} " \
    CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CFLAGS} -stdlib=libc++ -isystem ${SDKROOT}/usr/include"
  set +x

  make -j4 V=0
  make install
  AMRNBLIBLIST+=" ${ROOTDIR}/lib/libopencore-amrnb.a"
  AMRWBLIBLIST+=" ${ROOTDIR}/lib/libopencore-amrwb.a"

  make clean
  export PATH=${OLDPATH}
done

echo "Merge into universal binary."

cp -a ${SRCDIR}/amrnb/{interf_dec,interf_enc}.h ${AMRNBTARGETDIR}/Headers/
${LIPO} -create ${AMRNBLIBLIST} -output ${AMRNBTARGETDIR}/opencore-amrnb

cp -a ${SRCDIR}/amrwb/{dec_if,if_rom}.h ${AMRWBTARGETDIR}/Headers/
${LIPO} -create ${AMRWBLIBLIST} -output ${AMRWBTARGETDIR}/opencore-amrwb
