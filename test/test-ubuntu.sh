#!/usr/bin/bash

. ./test-startup.sh

docker build -t remote-ffmpeg -f ./Dockerfile.test-ubuntu . && \
docker run \
    --name remote-ffmpeg \
    --network=remote-ffmpeg-network \
    -e "REMOTE_FFMPEG_USER=ubuntu" \
    -e "REMOTE_FFMPEG_HOST=renderer" \
    -e "REMOTE_FFMPEG_PORT=6543" \
    -v $TEMP_SSH_DIR:/config/.ssh \
    remote-ffmpeg /usr/bin/remote-ffmpeg/ffmpeg "$@"
docker rm -f remote-ffmpeg

./test-teardown.sh