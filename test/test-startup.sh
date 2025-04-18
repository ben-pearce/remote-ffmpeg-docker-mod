#!/usr/bin/bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=0
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

TEMP_SSH_DIR=$(mktemp -d)

ssh-keygen -t ed25519 -f "$TEMP_SSH_DIR/id_ed25519" -N "" -C "ubuntu@renderer"
cp "$TEMP_SSH_DIR/id_ed25519.pub" "$TEMP_SSH_DIR/authorized_keys"
sudo chown -R 1000:1000 "$TEMP_SSH_DIR" && chmod 700 "$TEMP_SSH_DIR" && chmod 600 "$TEMP_SSH_DIR"/*

docker network create --driver bridge remote-ffmpeg-network

docker build -t sshd -f ./Dockerfile.sshd .
docker build -t remote-ffmpeg-mod ..

docker run --network=remote-ffmpeg-network \
    --cap-add SYS_ADMIN \
    --device /dev/fuse \
    --security-opt apparmor:unconfined \
    --privileged \
    --name renderer \
    -v $TEMP_SSH_DIR:/home/ubuntu/.ssh -d sshd

export TEMP_SSH_DIR