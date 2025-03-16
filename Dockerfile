# syntax=docker/dockerfile:1

# Howdy, need help? See
# https://photostructure.com/server/photostructure-for-docker/

# https://hub.docker.com/_/node/
FROM node:22.14-bookworm-slim AS builder

# 202208: We're building libraw and SQLite here to pick up the latest bugfixes.

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
  curl \
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
  && mkdir -p /tmp/libraw \
  && cd /tmp/libraw \
  && curl -L https://api.github.com/repos/LibRaw/LibRaw/tarball/09bea31181b43e97959ee5452d91e5bc66365f1f | tar -xz --strip 1 \
  && autoreconf -fiv \
  && ./configure --enable-static --disable-lcms --disable-openmp \
  && make -j `nproc` \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/dcraw_emu samples/bin_dcraw_emu-dcraw_emu.o lib/libraw.la -ljpeg -lz -lm \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/raw-identify samples/bin_raw_identify-raw-identify.o lib/libraw.la -ljpeg -lz -lm \
  && cp -p bin/dcraw_emu bin/raw-identify /opt/photostructure/tools/ \
  && rm -rf /tmp/libraw \
  && mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2025/sqlite-autoconf-3490100.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --disable-shared --enable-readline \
  && make -j `nproc` \
  && cp -p sqlite3 /opt/photostructure/tools/ \
  && rm -rf /tmp/sqlite \
  && strip /opt/photostructure/tools/*

# Stripped LibRaw and SQLite binaries should now be sitting in
# /opt/photostructure/tools/bin.
