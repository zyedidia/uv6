#!/bin/sh

mkdir -p build
cd build

export CC=/opt/lfi/toolchain/bin/lfi-clang
export CFLAGS="-DBUFSIZ=8192"

meson setup --cross-file ../lfi.txt \
    -Dtls-model=local-exec \
    -Dmultilib=false \
    -Dpicolib=false \
    -Dpicocrt=false \
    -Dpicocrt-lib=false \
    -Dsemihost=false \
    -Dposix-console=true \
    -Dnewlib-global-atexit=true \
    -Dprefix=$PWD/install \
    -Dincludedir=include \
    -Dlibdir=lib \
    -Dthread-local-storage=false \
    -Datomic-ungetc=false \
    -Dspecsdir=none \
    -Dfast-bufio=true \
    ../picolibc
ninja
ninja install
