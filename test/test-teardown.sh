#!/usr/bin/bash
docker stop renderer
docker rm -f renderer
docker network rm remote-ffmpeg-network

rm -r $TEMP_SSH_DIR

sudo sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=1
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=1
