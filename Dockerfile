# syntax=docker/dockerfile:1

# Howdy, need help? See
# https://photostructure.com/server/photostructure-for-docker/

# https://hub.docker.com/_/node/
# We use node:24 (not node:24.x) because native modules use N-API which is
# ABI-stable across Node versions. This allows automatic security patches.
FROM node:24-bookworm-slim AS builder

# 20260219: We're building libraw, SQLite, and jpegtran here to pick up the latest
# bugfixes and provide static binaries for all glibc-based editions of
# PhotoStructure.

# Note that libjpeg62, liblcms2, and liborc dev dependencies are used in the
# first build stage which starts from this image. By installing them here,
# that stage doesn't need to muck with `apt`.

# 20250315: instead of git, we're using GitHub REST API to download a specific
# commit of LibRaw. See
# https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives
# and
# https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#download-a-repository-archive-tar

RUN apt-get update \
  && apt-get upgrade -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  autoconf \
  autogen \
  automake \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  libblkid-dev \
  libjpeg62-turbo-dev \
  liblcms2-dev \
  liborc-0.4-dev \
  libreadline-dev \
  libtool \
  nasm \
  pkg-config \
  python3 \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && npm install --force --location=global npm yarn \
  && mkdir -p /opt/photostructure/tools \
  && mkdir -p /tmp/libraw \
  && cd /tmp/libraw \
  && curl -L https://api.github.com/repos/LibRaw/LibRaw/tarball/0b56545a4f828743f28a4345cdfdd4c49f9f9a2a | tar -xz --strip 1 \
  && autoreconf -fiv \
  && ./configure --enable-static --disable-lcms --disable-openmp \
  && make -j `nproc` \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/dcraw_emu samples/bin_dcraw_emu-dcraw_emu.o lib/libraw.la -ljpeg -lz -lm \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/raw-identify samples/bin_raw_identify-raw-identify.o lib/libraw.la -ljpeg -lz -lm \
  && cp -p bin/dcraw_emu bin/raw-identify /opt/photostructure/tools/ \
  && rm -rf /tmp/libraw \
  && mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2026/sqlite-autoconf-3510200.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --disable-shared --enable-readline \
  && make -j `nproc` \
  && cp -p sqlite3 /opt/photostructure/tools/ \
  && rm -rf /tmp/sqlite \
  && mkdir -p /tmp/jpegtran \
  && cd /tmp/jpegtran \
  && curl -L https://api.github.com/repos/libjpeg-turbo/libjpeg-turbo/tarball/af9c1c268520a29adf98cad5138dafe612b3d318 | tar -xz --strip 1 \
  && cmake -G "Unix Makefiles" -DENABLE_SHARED=0 -DENABLE_STATIC=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-static" -DCMAKE_EXE_LINKER_FLAGS="-static" \
  && make -j $(nproc) jpegtran-static \
  && cp -p jpegtran-static /opt/photostructure/tools/jpegtran \
  && rm -rf /tmp/jpegtran \
  && strip /opt/photostructure/tools/*

# Stripped LibRaw, SQLite, and jpegtran binaries should now be sitting in
# /opt/photostructure/tools/.
