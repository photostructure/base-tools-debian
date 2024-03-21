# syntax=docker/dockerfile:1

# Howdy, need help? See
# <https://photostructure.com/server/photostructure-for-docker/>

# https://hub.docker.com/_/node/
FROM node:20.11-bookworm-slim as builder

# 202208: We're building libraw and SQLite here to pick up the latest bugfixes.

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
  python3 \
  unzip \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && npm install --force --location=global npm yarn \
  && mkdir -p /opt/photostructure/tools \
  && git clone https://github.com/LibRaw/LibRaw.git /tmp/libraw \
  && cd /tmp/libraw \
  && git checkout --force a4c9b1981ee4ac2a144e7a290988428cc5bb7e85 \
  && autoreconf -fiv \
  && ./configure --prefix=/opt/photostructure/tools \
  && make -j `nproc` \
  && make install \
  && rm $(find /opt/photostructure/tools -type f | grep -vE "libraw.so|dcraw_emu|raw-identify") \
  && rmdir -p --ignore-fail-on-non-empty $(find /opt/photostructure/tools -type d) \ 
  && strip /opt/photostructure/tools/bin/* \
  && rm -rf /tmp/libraw \
  && mkdir -p /tmp/sqlite \
  && cd /tmp/sqlite \
  && curl https://sqlite.org/2024/sqlite-autoconf-3450200.tar.gz | tar -xz --strip 1 \
  && ./configure --enable-static --enable-readline \
  && make -j `nproc` \
  && strip sqlite3 \
  && cp -p sqlite3 /opt/photostructure/tools/bin \
  && rm -rf /tmp/sqlite

# Note: fully static binaries would be a bit more portable, but installing
# libjpeg isn't that big of a deal.

# Stripped LibRaw and SQLite binaries should now be sitting in
# /opt/photostructure/tools/bin.
