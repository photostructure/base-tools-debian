# syntax=docker/dockerfile:1

# Howdy, need help? See
# <https://photostructure.com/server/photostructure-for-docker/>

# https://hub.docker.com/_/node/
# "18-bullseye" was an alias for "lts-slim" on 2022-11-28
FROM node:18-bullseye-slim as builder

# 202208: We're building libraw and SQLite here to pick up the latest bugfixes.

# We're building static binaries here so we can skip installing the .so
# dependencies for the PhotoStructure for Docker image. It also allows us to
# re-use these binaries for the PhotoStructure for Node edition. Binary
# performance might be fractionally faster if we left these with dynamic
# links.

# Note that libjpeg62, liblcms2, and liborc dev dependencies are used in the
# first build stage which starts from this image. By installing them here,
# that stage doesn't need to muck with `apt`.

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
  liborc-0.4-dev \
  libtool \
  pkg-config \
  unzip \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && npm install --force --location=global npm yarn \
  && mkdir -p /ps/app/tools \
  && git clone https://github.com/LibRaw/LibRaw.git /tmp/libraw \
  && cd /tmp/libraw \
  && git checkout --force a5a5fb16936f0d3da0ea2ee92e43f508921c121a \
  && autoreconf -fiv \
  && ./configure --prefix=/ps/app/tools \
  && make -j `nproc` \
  && make install \
  && rm $(find /ps/app/tools -type f | grep -vE "libraw.so|dcraw_emu|raw-identify") \
  && rmdir -p --ignore-fail-on-non-empty $(find /ps/app/tools -type d) \ 
  && strip /ps/app/tools/bin/* \
  && rm -rf /tmp/libraw
  
RUN mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2022/sqlite-autoconf-3400000.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --enable-readline \
  && make -j `nproc` \
  && strip sqlite3 \
  && cp -p sqlite3 /ps/app/tools/bin \
  && rm -rf /tmp/sqlite

# Note: fully static binaries would be a bit more portable, but installing
# libjpeg isn't that big of a deal.

# Stripped LibRaw and SQLite binaries should now be sitting in
# /ps/app/tools/bin.

# docker build -t photostructure/base-glibc-tools .
