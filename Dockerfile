ARG BUBBLEWRAP_VERSION="0.11.0"
ARG LIBFUSE_VERSION="3.17.1"
ARG SSHFS_VERSION="3.7.3"
ARG LIBFUSE_URL="https://github.com/libfuse/libfuse/releases/download/fuse-${LIBFUSE_VERSION}/fuse-${LIBFUSE_VERSION}.tar.gz"
ARG SSHFS_URL="https://github.com/libfuse/sshfs/releases/download/sshfs-${SSHFS_VERSION}/sshfs-${SSHFS_VERSION}.tar.xz"
ARG BUBBLEWRAP_URL="https://github.com/containers/bubblewrap/releases/download/v${BUBBLEWRAP_VERSION}/bubblewrap-${BUBBLEWRAP_VERSION}.tar.xz"

FROM ubuntu:noble@sha256:72297848456d5d37d1262630108ab308d3e9ec7ed1c3286a32fe09856619a782 AS sshfs-glibc
ARG SSHFS_VERSION
ARG LIBFUSE_VERSION
ARG LIBFUSE_URL
ARG SSHFS_URL

RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
RUN apt update && apt install -y \
    curl \
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

FROM alpine:3.21.3 AS sshfs-musl
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

FROM ubuntu:noble@sha256:72297848456d5d37d1262630108ab308d3e9ec7ed1c3286a32fe09856619a782 AS bwrap-glibc
ARG BUBBLEWRAP_URL
ARG BUBBLEWRAP_VERSION

RUN apt update && apt install -y \
    curl \
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

FROM alpine:3.21.3 AS bwrap-musl
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

FROM ghcr.io/linuxserver/baseimage-alpine:3.21@sha256:8d50d1646ce3e59accad6837331122a1dd67ebd77d72cf759cd0531ba7c93b51 AS buildstage
ARG SSHFS_VERSION
ARG BUBBLEWRAP_VERSION
COPY root/ /root-layer/
COPY --from=sshfs-glibc /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /root-layer/usr/bin/glibc-sshfs
COPY --from=sshfs-musl /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /root-layer/usr/bin/musl-sshfs
COPY --from=bwrap-glibc /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /root-layer/usr/bin/glibc-bwrap
COPY --from=bwrap-musl /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /root-layer/usr/bin/musl-bwrap

FROM scratch
COPY --from=buildstage /root-layer/ /
