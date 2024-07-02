# syntax=docker/dockerfile:1

# Howdy, need help? See
# <https://photostructure.com/server/photostructure-for-docker/>

# https://hub.docker.com/_/node/
FROM node:20.15-bookworm-slim as builder

# 202208: We're building libraw and SQLite here to pick up the latest bugfixes.

# Note that libjpeg62, liblcms2, and liborc dev dependencies are used in the
# first build stage which starts from this image. By installing them here,
# that stage doesn't need to muck with `apt`.

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
  autoconf \
  autogen \
  automake \
  build-essential \
  ca-certificates \
  curl \
  git \
  libjpeg62-turbo-dev \
  liblcms2-dev \
  liborc-0.4-dev \
  libreadline-dev \
  libtool \
  pkg-config \
  python3 \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && npm install --force --location=global npm yarn \
  && mkdir -p /opt/photostructure/tools \
  && git clone https://github.com/LibRaw/LibRaw.git /tmp/libraw \
  && cd /tmp/libraw \
  && git checkout --force d3cbbd0e9934898eb28e4963ee99b51928e2acaa \
  && autoreconf -fiv \
  && ./configure --enable-static --disable-lcms --disable-openmp \
  && make -j `nproc` \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/dcraw_emu samples/bin_dcraw_emu-dcraw_emu.o lib/libraw.la -ljpeg -lz -lm \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/raw-identify samples/bin_raw_identify-raw-identify.o lib/libraw.la -ljpeg -lz -lm \
  && cp -p bin/dcraw_emu bin/raw-identify /opt/photostructure/tools/ \
  && rm -rf /tmp/libraw \
  && mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2024/sqlite-autoconf-3460000.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --disable-shared --enable-readline \
  && make -j `nproc` \
  && cp -p sqlite3 /opt/photostructure/tools/ \
  && rm -rf /tmp/sqlite \
  && strip /opt/photostructure/tools/*

# Stripped LibRaw and SQLite binaries should now be sitting in
# /opt/photostructure/tools/bin.
