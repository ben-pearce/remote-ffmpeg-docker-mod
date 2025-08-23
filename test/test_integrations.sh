#!/usr/bin/bash

. ./common/environment.sh
. ./common/ffmpeg.sh

setup_suite() {
    setup_apparmor_restrictions
    setup_renderer_mock
}

test_jellyfin() {
    max_attempts=120
    attempts=0
    name=remote-ffmpeg-jellyfin
    docker build -qt "$name" -f "./images/Dockerfile.test-jellyfin" . > /dev/null
    docker run -d --name "$name" \
        --network=remote-ffmpeg-network \
        -e "REMOTE_FFMPEG_USER=ubuntu" \
        -e "REMOTE_FFMPEG_HOST=renderer" \
        -e "REMOTE_FFMPEG_PORT=6543" \
        -e REMOTE_FFMPEG_BINARY=/usr/lib/jellyfin-ffmpeg/ffmpeg \
        -e FFMPEG_PATH=/usr/bin/remote-ffmpeg/ffmpeg \
        -e PUID=1000 \
        -e PGID=1000 \
        -e TZ=Europe/London \
        -v "$TEMP_SSH_DIR":/config/.ssh \
        "$name" > /dev/null
    until docker logs "$name" 2>&1 | grep -q '\[ls.io-init\] done.'; do
        if (( attempts++ >= max_attempts )); then
            docker stop "$name"
            docker rm -f "$name"
    
            assert false "Timed out waiting for jellyfin boot sequence."
        fi
        sleep 1
    done

    docker stop "$name" > /dev/null
    docker rm -f "$name" > /dev/null

    assert true
}

teardown_suite() {
    teardown_renderer_mock
    teardown_apparmor_restrictions
}