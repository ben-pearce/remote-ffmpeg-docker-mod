#!/usr/bin/bash

TEMP_SSH_DIR=$(mktemp -d)

setup_renderer_mock() {
    ssh-keygen -q -t ed25519 -f "$TEMP_SSH_DIR/id_ed25519" -N "" -C "ubuntu@renderer"
    cp "$TEMP_SSH_DIR/id_ed25519.pub" "$TEMP_SSH_DIR/authorized_keys"
    chown -R 1000:1000 "$TEMP_SSH_DIR" && chmod 700 "$TEMP_SSH_DIR" && chmod 600 "$TEMP_SSH_DIR"/*

    docker network create --driver bridge remote-ffmpeg-network > /dev/null

    docker build -qt sshd -f ./images/Dockerfile.sshd . > /dev/null
    docker run --network=remote-ffmpeg-network \
        --rm \
        --cap-add SYS_ADMIN \
        --device /dev/fuse \
        --security-opt apparmor:unconfined \
        --privileged \
        --name renderer \
        -v "$TEMP_SSH_DIR":/home/ubuntu/.ssh -d sshd > /dev/null
}

teardown_renderer_mock() {
    docker stop renderer > /dev/null
    docker network rm remote-ffmpeg-network > /dev/null

    rm -r "$TEMP_SSH_DIR"
}

setup_proxy_mock() {
    docker build -qt nginx -f ./images/Dockerfile.nginx . > /dev/null
    docker run -q --network=remote-ffmpeg-network \
        --name remote-ffmpeg-nginx \
        -v ./www:/usr/share/nginx/html \
        -d nginx > /dev/null
}

teardown_proxy_mock() {
    docker rm -f remote-ffmpeg-nginx > /dev/null
}

setup_apparmor_restrictions() {
    sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=0 > /dev/null
    sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 > /dev/null
}

teardown_apparmor_restrictions() {
    sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=1 > /dev/null
    sysctl -w kernel.apparmor_restrict_unprivileged_userns=1 > /dev/null
}