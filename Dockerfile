# syntax=docker/dockerfile:1

# Howdy, need help? See
# https://photostructure.com/server/photostructure-for-docker/

FROM alpine:3.23 AS sqlite-builder

# A static glibc shell can dlopen the host's NSS modules for getpwuid(),
# bringing in an incompatible host libc. Build the portable CLI with musl.
# --enable-static and --disable-shared cover libsqlite3 only;
# --static-cli-shell links the shell itself without Alpine's runtime loader.
RUN apk add --no-cache build-base ca-certificates curl ncurses-static \
  readline-dev readline-static zlib-dev zlib-static \
  && mkdir -p /tmp/sqlite /opt/photostructure/tools \
  && cd /tmp/sqlite \
  && curl -fLsS -o sqlite.tar.gz https://sqlite.org/2026/sqlite-autoconf-3530400.tar.gz \
  && echo '0e9483900e92cd5de8fd48d16bf9200145a61f7fd5be542a5ac81d8a9516eb9c  sqlite.tar.gz' | sha256sum -c - \
  && tar -xzf sqlite.tar.gz --strip 1 \
  && ./configure --enable-static --disable-shared --enable-readline --static-cli-shell \
  && make -j `nproc` sqlite3 \
  && strip sqlite3 \
  && cp sqlite3 /opt/photostructure/tools/

FROM node:24-trixie-slim AS builder

# Node.js uses N-API, which is ABI-stable across Node 24 patch versions. The
# unpinned patch version picks up security updates.

# 20260803: We're building libraw and jpegtran here to pick up the latest
# bugfixes and provide static binaries for all glibc-based editions of
# PhotoStructure. SQLite comes from the musl stage above.

# libjpeg62-turbo-dev links LibRaw here. PhotoStructure's server/Dockerfile
# builder stage starts from this image and also needs libjpeg62-turbo-dev,
# liblcms2-dev, and liborc-0.4-dev, so keep them here for that stage.

# 20260921: Static glibc fixed the older-host startup failure but still loads
# host NSS libraries. On Ubuntu 24.04 with passwd: compat, this caused SIGFPE
# during SQLite shell startup. The musl stage avoids that runtime dependency.

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
  && curl -L https://api.github.com/repos/LibRaw/LibRaw/tarball/b93f6e45c194f5df9b02a43b1af9a54b4f41f33f | tar -xz --strip 1 \
  && autoreconf -fiv \
  && ./configure --enable-static --disable-lcms --disable-openmp \
  && make -j `nproc` \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/dcraw_emu samples/bin_dcraw_emu-dcraw_emu.o lib/libraw.la -ljpeg -lz -lm \
  && /bin/bash ./libtool --tag=CXX --mode=link g++ -all-static -g -O2 -o bin/raw-identify samples/bin_raw_identify-raw-identify.o lib/libraw.la -ljpeg -lz -lm \
  && cp -p bin/dcraw_emu bin/raw-identify /opt/photostructure/tools/ \
  && rm -rf /tmp/libraw \
  && mkdir -p /tmp/jpegtran \
  && cd /tmp/jpegtran \
  && curl -L https://api.github.com/repos/libjpeg-turbo/libjpeg-turbo/tarball/c85e6b905bf237038faa936dab160ebfc5da0344 | tar -xz --strip 1 \
  && cmake -G "Unix Makefiles" -DENABLE_SHARED=0 -DENABLE_STATIC=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-static" -DCMAKE_EXE_LINKER_FLAGS="-static" \
  && make -j $(nproc) jpegtran-static \
  && cp -p jpegtran-static /opt/photostructure/tools/jpegtran \
  && rm -rf /tmp/jpegtran \
  && strip /opt/photostructure/tools/*

COPY --from=sqlite-builder /opt/photostructure/tools/sqlite3 /opt/photostructure/tools/sqlite3

# Stripped LibRaw, SQLite, and jpegtran binaries should now be sitting in
# /opt/photostructure/tools/.
