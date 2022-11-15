# syntax=docker/dockerfile:1

# Howdy, need help? See
# <https://photostructure.com/server/photostructure-for-docker/>

# https://hub.docker.com/_/node/
# TODO: migrate to lts-slim (Node 18)
FROM node:16-bullseye-slim as builder

# 202208: We're building libraw and SQLite here to pick up the latest bugfixes.

# We're building static binaries here so we can skip installing the .so
# dependencies for the PhotoStructure for Docker image. It also allows us to
# re-use these binaries for the PhotoStructure for Node edition. Binary
# performance might be fractionally faster if we left these with dynamic
# links.

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
  autoconf \
  autogen \
  build-essential \
  curl \
  git \
  libjpeg62-turbo-dev \
  liblcms2-dev \
  libtool \
  pkg-config \
  unzip \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*
  
RUN git clone https://github.com/LibRaw/LibRaw.git /tmp/libraw \
  && cd /tmp/libraw \
  && git checkout --force a5a5fb16936f0d3da0ea2ee92e43f508921c121a \
  && autoreconf -fiv \
  && ./configure --enable-static --disable-lcms --disable-openmp \
  && make -j `nproc` \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/dcraw_emu samples/bin_dcraw_emu-dcraw_emu.o lib/libraw.la -ljpeg -lz -lm \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/raw-identify samples/bin_raw_identify-raw-identify.o lib/libraw.la -ljpeg -lz -lm \
  && mkdir -p /ps/app/tools/bin \
  && strip bin/dcraw_emu \
  && strip bin/raw-identify \
  && cp -p bin/dcraw_emu bin/raw-identify /ps/app/tools/bin \
  && rm -rf /tmp/libraw
  
RUN mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2022/sqlite-autoconf-3390400.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --enable-readline \
  && make -j `nproc` \
  && strip sqlite3 \
  && cp -p sqlite3 /ps/app/tools/bin \
  && rm -rf /tmp/sqlite

# Stripped LibRaw and SQLite binaries should now be sitting in /ps/app/tools/bin.

# docker build -t photostructure/base-glibc-tools .
