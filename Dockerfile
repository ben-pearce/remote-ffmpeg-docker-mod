ARG BUBBLEWRAP_VERSION="0.11.0"
ARG LIBFUSE_VERSION="3.17.1"
ARG SSHFS_VERSION="3.7.3"
ARG LIBFUSE_URL="https://github.com/libfuse/libfuse/releases/download/fuse-${LIBFUSE_VERSION}/fuse-${LIBFUSE_VERSION}.tar.gz"
ARG SSHFS_URL="https://github.com/libfuse/sshfs/releases/download/sshfs-${SSHFS_VERSION}/sshfs-${SSHFS_VERSION}.tar.xz"
ARG BUBBLEWRAP_URL="https://github.com/containers/bubblewrap/releases/download/v${BUBBLEWRAP_VERSION}/bubblewrap-${BUBBLEWRAP_VERSION}.tar.xz"

FROM ubuntu:noble@sha256:1e622c5f073b4f6bfad6632f2616c7f59ef256e96fe78bf6a595d1dc4376ac02 AS sshfs-glibc
ARG SSHFS_VERSION
ARG LIBFUSE_VERSION
ARG LIBFUSE_URL
ARG SSHFS_URL

RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN apt update && apt install -y \
    curl \
    pkg-config \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libglib2.0-dev \
    cmake \
    python3 \
    meson \
    ninja-build
RUN apt build-dep -y g++

RUN curl -s -L ${LIBFUSE_URL} | tar xfz - -C /tmp
RUN mkdir /tmp/fuse-${LIBFUSE_VERSION}/build
WORKDIR /tmp/fuse-${LIBFUSE_VERSION}/build
RUN LDFLAGS="-static" meson setup \
    -Dexamples=false \
    -Dtests=false \
    -Ddefault_library=static \
    --prefix=/tmp/libfuse ..
RUN ninja

RUN curl -s -L ${SSHFS_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/sshfs-${SSHFS_VERSION}/build
WORKDIR /tmp/sshfs-${SSHFS_VERSION}/build

RUN PKG_CONFIG_PATH=/tmp/fuse-${LIBFUSE_VERSION}/build/meson-private \
    LDFLAGS="-static" meson setup \
    -Ddefault_library=static \
    --prefix=/tmp/sshfs ..
RUN meson configure \
    -Dc_args="-I/tmp/fuse-${LIBFUSE_VERSION}/build -I/tmp/fuse-${LIBFUSE_VERSION}/include" \
    -Dc_link_args=-L/tmp/fuse-${LIBFUSE_VERSION}/build/lib
RUN ninja

FROM alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS sshfs-musl
ARG SSHFS_VERSION
ARG LIBFUSE_VERSION
ARG LIBFUSE_URL
ARG SSHFS_URL

RUN apk add --no-cache \
    build-base \
    cmake \
    python3 \
    py3-pip \
    meson \
    ninja \
    curl \
    gcompat \
    libstdc++ \
    libstdc++-dev \
    pkgconf \
    musl-dev \
    gmp-dev \
    mpfr-dev \
    mpc1-dev \
    glib-dev \
    glib-static \
    pcre2-dev
    
ENV LDFLAGS="-static"
ENV CC=gcc

RUN curl -s -L ${LIBFUSE_URL} | tar xfz - -C /tmp
RUN mkdir /tmp/fuse-${LIBFUSE_VERSION}/build
WORKDIR /tmp/fuse-${LIBFUSE_VERSION}/build
RUN LDFLAGS="-static" meson setup \
    -Dexamples=false \
    -Dtests=false \
    -Ddefault_library=static \
    --prefix=/tmp/libfuse ..
RUN ninja

RUN curl -s -L ${SSHFS_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/sshfs-${SSHFS_VERSION}/build
WORKDIR /tmp/sshfs-${SSHFS_VERSION}/build
RUN PKG_CONFIG_PATH=/tmp/fuse-${LIBFUSE_VERSION}/build/meson-private \
    LDFLAGS="-static" \
    meson setup \
    -Ddefault_library=static \
    --prefix=/tmp/sshfs ..
RUN meson configure \
    -Dc_args="-I/tmp/fuse-${LIBFUSE_VERSION}/build -I/tmp/fuse-${LIBFUSE_VERSION}/include" \
    -Dc_link_args="-L/tmp/fuse-${LIBFUSE_VERSION}/build/lib"
RUN ninja

FROM ubuntu:noble@sha256:1e622c5f073b4f6bfad6632f2616c7f59ef256e96fe78bf6a595d1dc4376ac02 AS bwrap-glibc
ARG BUBBLEWRAP_URL
ARG BUBBLEWRAP_VERSION

RUN apt update && apt install -y \
    curl \
    pkg-config \
    libcap-dev \
    libselinux1-dev \
    cmake \
    python3 \
    meson \ 
    ninja-build

RUN curl -s -L ${BUBBLEWRAP_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build
WORKDIR /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build

ENV LDFLAGS="-static"
RUN meson setup --prefer-static .. -Ddefault_library=static
RUN ninja

FROM alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS bwrap-musl
ARG BUBBLEWRAP_URL
ARG BUBBLEWRAP_VERSION

RUN apk add --no-cache \
    bash \
    bash-completion \
    linux-headers \
    build-base \
    cmake \
    pkgconf \
    python3 \
    py3-pip \
    meson \
    curl \
    ninja \
    musl-dev \
    libcap-dev \
    libcap-static \
    libxslt

RUN curl -s -L ${BUBBLEWRAP_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build
WORKDIR /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build

RUN PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig \
    LDFLAGS="-static" meson setup \
    --prefer-static \
    -Ddefault_library=static \
    -Dselinux=disabled ..
RUN ninja

FROM ghcr.io/linuxserver/baseimage-alpine:3.21@sha256:4a4c3b6a8e1dd333654fd194fe91ed5786f15b52431e6a5c9f020daf7a3f37c4 AS buildstage
ARG SSHFS_VERSION
ARG BUBBLEWRAP_VERSION
COPY root/ /root-layer/
COPY --from=sshfs-glibc /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /root-layer/usr/bin/glibc-sshfs
COPY --from=sshfs-musl /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /root-layer/usr/bin/musl-sshfs
COPY --from=bwrap-glibc /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /root-layer/usr/bin/glibc-bwrap
COPY --from=bwrap-musl /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /root-layer/usr/bin/musl-bwrap

FROM scratch
COPY --from=buildstage /root-layer/ /
