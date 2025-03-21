ARG BUBBLEWRAP_VERSION="0.11.0"
ARG LIBFUSE_VERSION="3.16.2"
ARG SSHFS_VERSION="3.7.3"
ARG LIBFUSE_URL="https://github.com/libfuse/libfuse/releases/download/fuse-${LIBFUSE_VERSION}/fuse-${LIBFUSE_VERSION}.tar.gz"
ARG SSHFS_URL="https://github.com/libfuse/sshfs/releases/download/sshfs-${SSHFS_VERSION}/sshfs-${SSHFS_VERSION}.tar.xz"
ARG BUBBLEWRAP_URL="https://github.com/containers/bubblewrap/releases/download/v${BUBBLEWRAP_VERSION}/bubblewrap-${BUBBLEWRAP_VERSION}.tar.xz"

FROM ghcr.io/linuxserver/baseimage-alpine:3.19 AS buildstage
COPY root/ /root-layer/

FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy AS sshfs-glibc
ARG SSHFS_VERSION
ARG LIBFUSE_VERSION
ARG LIBFUSE_URL
ARG SSHFS_URL

RUN apt update && apt install -y \
    pkg-config \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libglib2.0-dev \
    cmake \
    python3 \
    python3-pip
RUN apt build-dep -y g++
RUN pip3 install meson ninja

RUN curl -s -L ${LIBFUSE_URL} | tar xfz - -C /tmp
RUN mkdir /tmp/fuse-${LIBFUSE_VERSION}/build
WORKDIR /tmp/fuse-${LIBFUSE_VERSION}/build
RUN LDFLAGS="-static" meson setup \
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

FROM alpine:latest AS sshfs-musl
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

FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy AS bwrap-glibc
ARG BUBBLEWRAP_URL
ARG BUBBLEWRAP_VERSION

RUN apt update && apt install -y \
    pkg-config \
    libcap-dev \
    libselinux1-dev \
    cmake \
    python3 \
    python3-pip
RUN pip3 install meson ninja

RUN curl -s -L ${BUBBLEWRAP_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build
WORKDIR /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build

ENV LDFLAGS="-static"
RUN meson setup --prefer-static .. -Ddefault_library=static
RUN ninja

FROM alpine:latest AS bwrap-musl
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

FROM scratch
ARG SSHFS_VERSION
ARG BUBBLEWRAP_VERSION
COPY --from=buildstage /root-layer/ /
COPY --from=sshfs-glibc /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /usr/bin/glibc-sshfs
COPY --from=sshfs-musl /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /usr/bin/musl-sshfs
COPY --from=bwrap-glibc /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /usr/bin/glibc-bwrap
COPY --from=bwrap-musl /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /usr/bin/musl-bwrap