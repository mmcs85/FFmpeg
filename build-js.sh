#!/bin/bash -x

set -e -o pipefail

NPROC=$(grep -c ^processor /proc/cpuinfo)
ROOT_DIR=$PWD
BUILD_DIR=$ROOT_DIR/build
EM_TOOLCHAIN_FILE=/emsdk_portable/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
PTHREAD_FLAGS='-s USE_PTHREADS=1'

export CFLAGS=$PTHREAD_FLAGS
export CPPFLAGS=$PTHREAD_FLAGS
export LDFLAGS=$PTHREAD_FLAGS

clean_up() {
  rm -rf $BUILD_DIR
}

build_zlib() {
  cd third_party/zlib
  rm -rf build zconf.h
  mkdir build
  cd build
  emmake cmake .. \
    -DCMAKE_INSTALL_PREFIX=${BUILD_DIR} \
    -DCMAKE_TOOLCHAIN_FILE=${EM_TOOLCHAIN_FILE} \
    -DBUILD_SHARED_LIBS=OFF
  emmake make clean
  emmake make install -j${NPROC}
  cd ${ROOT_DIR}
}

build_x264() {
  cd third_party/x264
  emconfigure ./configure \
    --enable-static \
    --disable-cli \
    --disable-asm \
    --host=i686-linux \
    --prefix=$BUILD_DIR
  emmake make clean
  emmake make install-lib-static -j${NPROC}
  cd ${ROOT_DIR}
}

build_libmp3lame() {
  cd third_party/libmp3lame
  emconfigure ./configure \
    --enable-shared=no \
    --host=i686-linux \
    --prefix=${BUILD_DIR}
  emmake make clean
  emmake make install -j${NPROC}
  cd ${ROOT_DIR}
}

configure_ffmpeg() {
  emconfigure ./configure \
    --disable-openssl \
    --disable-xmm-clobber-test \
    --disable-neon-clobber-test \
    --disable-programs \
    --disable-postproc \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-sndio \
    --disable-schannel \
    --disable-securetransport \
    --disable-xlib \
    --disable-cuda \
    --disable-cuvid \
    --disable-nvenc \
    --disable-vaapi \
    --disable-vdpau \
    --disable-videotoolbox \
    --disable-audiotoolbox \
    --disable-appkit \
    --disable-alsa \
    --disable-cuda \
    --disable-cuvid \
    --disable-nvenc \
    --disable-vaapi \
    --disable-vdpau \
    --disable-gray \
    --disable-network \
    --disable-postproc \
    --disable-pixelutils \
    --disable-encoders \
    --disable-decoders \
    --disable-muxers \
    --disable-parsers \
    --disable-bsfs \
    --disable-protocols \
    --disable-devices \
    --disable-demuxers \
    \
    --enable-avcodec \
    --enable-avformat \
    --enable-avfilter \
    --enable-swresample \
    --enable-swscale \
    \
    --enable-filter=anull,aresample,scale,crop,overlay,hstack,vstack \
    --enable-parser=h264,aac,mpeg4video,mjpeg \
    --enable-demuxer=mov,aac,mp3,image2,gif,concat \
    --enable-decoder=h264,h264_cuvid,h264_mediacodec,h264_mmal,h264_qsv,h264_rkmpp,h264_v4l2m2m,mp3,aac,mjpeg,png,gif \
    --enable-muxer=mp4 \
    --enable-encoder=libx264,aac \
    \
    --enable-protocol=file \
    --enable-gpl \
    --enable-libx264 \
    --enable-libmp3lame \
    --enable-cross-compile \
    --disable-x86asm \
    --disable-inline-asm \
    --disable-doc \
    --disable-stripping \
    --disable-ffprobe \
    --disable-ffplay \
    --disable-ffmpeg \
    --ignore-tests=$(cat all-tests) \
    --prefix=$BUILD_DIR \
    --extra-cflags="-I$BUILD_DIR/include" \
    --extra-cxxflags="-I$BUILD_DIR/include" \
    --extra-ldflags="-L$BUILD_DIR/lib" \
    --arch=i686 \
    --nm="llvm-nm -g" \
    --ar=emar \
    --as=llvm-as \
    --ranlib=llvm-ranlib \
    --cc=emcc \
    --cxx=em++ \
    --objcc=emcc \
    --dep-cc=emcc
}

make_ffmpeg() {
  emmake make clean
  emmake make -j${NPROC}
}

build_ffmpegjs() {
  emcc \
    -I. -I./fftools -I$BUILD_DIR/include \
    -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavresample -Llibavutil -Llibpostproc -Llibswscale -Llibswresample -Llibpostproc -L${BUILD_DIR}/lib \
    -Qunused-arguments -O3 \
    -o $2 fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c \
    -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lpostproc -lm -lx264 -lz -lmp3lame \
    -Wno-deprecated-declarations -Wno-pointer-sign -Wno-implicit-int-float-conversion -Wno-switch -Wno-parentheses \
    --pre-js javascript/prepend.js \
    --post-js javascript/post.js \
    -s USE_SDL=2 \
    $PTHREAD_FLAGS \
    -s INVOKE_RUN=0 \
    -s PTHREAD_POOL_SIZE=8 \
    -s PROXY_TO_PTHREAD=1 \
    -s SINGLE_FILE=$1 \
    -s EXPORTED_FUNCTIONS="[_main, _proxy_main]" \
    -s EXTRA_EXPORTED_RUNTIME_METHODS="[cwrap, FS, getValue, setValue]" \
    -s TOTAL_MEMORY=1065353216
}

main() {
  clean_up
  build_zlib
  build_x264
  build_libmp3lame
  configure_ffmpeg
  make_ffmpeg
  build_ffmpegjs 1 dist/ffmpeg-core.js
  build_ffmpegjs 0 dist-wasm/ffmpeg-core.js
}

main "$@"


