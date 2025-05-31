ARG BUBBLEWRAP_VERSION="0.11.0"
ARG LIBFUSE_VERSION="3.17.2"
ARG SSHFS_VERSION="3.7.3"
ARG LIBFUSE_URL="https://github.com/libfuse/libfuse/releases/download/fuse-${LIBFUSE_VERSION}/fuse-${LIBFUSE_VERSION}.tar.gz"
ARG SSHFS_URL="https://github.com/libfuse/sshfs/releases/download/sshfs-${SSHFS_VERSION}/sshfs-${SSHFS_VERSION}.tar.xz"
ARG BUBBLEWRAP_URL="https://github.com/containers/bubblewrap/releases/download/v${BUBBLEWRAP_VERSION}/bubblewrap-${BUBBLEWRAP_VERSION}.tar.xz"

FROM alpine:3.22.0@sha256:8a1f59ffb675680d47db6337b49d22281a139e9d709335b492be023728e11715 AS sshfs
ARG SSHFS_VERSION
ARG LIBFUSE_VERSION
ARG LIBFUSE_URL
ARG SSHFS_URL

RUN apk add --no-cache \
    build-base \
    meson \
    ninja \
    curl \
    pkgconf \
    musl-dev \
    glib-dev \
    glib-static \
    pcre2-dev \
    zlib-static \
    gettext-static

RUN curl -s -L ${LIBFUSE_URL} | tar xfz - -C /tmp
RUN mkdir /tmp/fuse-${LIBFUSE_VERSION}/build
WORKDIR /tmp/fuse-${LIBFUSE_VERSION}/build
RUN LDFLAGS="-static" meson setup \
    -Dexamples=false \
    -Dtests=false \
    -Ddefault_library=static \
    --prefix=/tmp/fuse-${LIBFUSE_VERSION} ..
RUN ninja

RUN curl -s -L ${SSHFS_URL} | tar xfJ - -C /tmp
RUN sed -i 's/dependency(\(.*fuse3.*\))/dependency(\1, static: true)/' /tmp/sshfs-${SSHFS_VERSION}/meson.build \
    && sed -i 's/dependency(\(.*glib-2.0.*\))/dependency(\1, static: true)/' /tmp/sshfs-${SSHFS_VERSION}/meson.build \
    && sed -i 's/dependency(\(.*gthread-2.0.*\))/dependency(\1, static: true)/' /tmp/sshfs-${SSHFS_VERSION}/meson.build

RUN mkdir /tmp/sshfs-${SSHFS_VERSION}/build
WORKDIR /tmp/sshfs-${SSHFS_VERSION}/build
RUN PKG_CONFIG_PATH="/tmp/fuse-${LIBFUSE_VERSION}/build/meson-private:/usr/lib/pkgconfig" \
    CFLAGS="-static -I/tmp/fuse-${LIBFUSE_VERSION}/build -I/tmp/fuse-${LIBFUSE_VERSION}/include" \
    LDFLAGS="-static -L/tmp/fuse-${LIBFUSE_VERSION}/build/lib -lfuse3" \
    meson setup /tmp/sshfs-${SSHFS_VERSION} \
        -Ddefault_library=static \
        --prefix=/tmp/sshfs-${SSHFS_VERSION}
RUN ninja

FROM alpine:3.22.0@sha256:8a1f59ffb675680d47db6337b49d22281a139e9d709335b492be023728e11715 AS bwrap
ARG BUBBLEWRAP_URL
ARG BUBBLEWRAP_VERSION

RUN apk add --no-cache \
    bash-completion \
    linux-headers \
    build-base \
    pkgconf \
    meson \
    curl \
    ninja \
    musl-dev \
    libcap-dev \
    libcap-static

RUN curl -s -L ${BUBBLEWRAP_URL} | tar xfJ - -C /tmp
RUN mkdir /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build
WORKDIR /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build

RUN PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/local/lib/pkgconfig \
    LDFLAGS="-static" meson setup \
    --prefer-static \
    -Ddefault_library=static \
    -Dselinux=disabled ..
RUN ninja

FROM ghcr.io/linuxserver/baseimage-alpine:3.21@sha256:67550302697496226f39930eab2f7d678aa66ed67b941bfaf0676019c4b18fbc AS buildstage
ARG SSHFS_VERSION
ARG BUBBLEWRAP_VERSION
COPY root/ /root-layer/
COPY --from=sshfs /tmp/sshfs-${SSHFS_VERSION}/build/sshfs /root-layer/usr/bin/sshfs
COPY --from=bwrap /tmp/bubblewrap-${BUBBLEWRAP_VERSION}/build/bwrap /root-layer/usr/bin/bwrap

FROM scratch
COPY --from=buildstage /root-layer/ /
