#!/bin/sh
### Modified from http://blog.csdn.net/favormm/article/details/6772097
set -xe

DEVELOPER=`xcode-select -print-path`
DEST=`pwd .`"/opencore-amr-iOS"
 
ARCHS="i386 armv7 armv7s"
LIBS="libopencore-amrnb.a libopencore-amrwb.a"
# Note that AMR-NB is for narrow band http://en.wikipedia.org/wiki/Adaptive_Multi-Rate_audio_codec
# for AMR-WB encoding, refer to http://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/
# or AMR Codecs as Shared Libraries http://www.penguin.cz/~utx/amr

CC_OVERRIDE="gcc"
CXX_OVERRIDE="g++"

mkdir -p $DEST

./configure

for arch in $ARCHS; do
	make clean
	case $arch in
	arm*)
		echo "Building opencore-amr for iPhoneOS $arch ****************"
		PATH=`xcodebuild -version -sdk iphoneos PlatformPath`"/Developer/usr/bin:$PATH"
		SDK=`xcodebuild -version -sdk iphoneos Path`
		CC="$CC_OVERRIDE -arch $arch --sysroot=$SDK" CXX="$CXX_OVERRIDE -arch $arch --sysroot=$SDK" \
		LDFLAGS="-Wl,-syslibroot,$SDK" ./configure \
		--host=arm-apple-darwin --prefix=$DEST \
		--disable-shared --enable-gcc-armv5
		;;
	*)
		echo "Building opencore-amr for iPhoneSimulator $arch *****************"
		PATH=`xcodebuild -version -sdk iphonesimulator PlatformPath`"/Developer/usr/bin:$PATH"
		CC="$CC_OVERRIDE -arch $arch" CXX="$CXX_OVERRIDE -arch $arch" \
		./configure \
		--prefix=$DEST \
		--disable-shared
		;;
	esac
	make -j3
	make install
	for i in $LIBS; do
		mv $DEST/lib/$i $DEST/lib/$i.$arch
	done
done

echo "Merge into universal binary."

for i in $LIBS; do
	input=""
	for arch in $ARCHS; do
		input="$input $DEST/lib/$i.$arch"
	done
	lipo -create -output $DEST/lib/$i $input
done



