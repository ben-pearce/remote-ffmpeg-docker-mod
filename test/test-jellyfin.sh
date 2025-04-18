#!/usr/bin/bash

. ./test-startup.sh

docker build -t remote-ffmpeg-jellyfin -f ./Dockerfile.test-jellyfin . && \
docker run -d \
    --name remote-ffmpeg-jellyfin \
    --network=remote-ffmpeg-network \
    -e "REMOTE_FFMPEG_USER=ubuntu" \
    -e "REMOTE_FFMPEG_HOST=renderer" \
    -e "REMOTE_FFMPEG_PORT=6543" \
    -e REMOTE_FFMPEG_BINARY=/usr/lib/jellyfin-ffmpeg/ffmpeg \
    -e FFMPEG_PATH=/usr/bin/remote-ffmpeg/ffmpeg \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=Europe/London \
    -v ./config:/config/ \
    -v ./config/tvseries:/data/tvshows \
    -v ./config/movies:/data/movies \
    -v $TEMP_SSH_DIR:/config/.ssh \
    remote-ffmpeg-jellyfin
while ! docker logs remote-ffmpeg-jellyfin | grep -q "Main: Startup complete" ; do sleep 1; done

docker exec -it -u abc remote-ffmpeg-jellyfin /usr/bin/remote-ffmpeg/ffmpeg
docker stop remote-ffmpeg-jellyfin
docker rm -f remote-ffmpeg-jellyfin

./test-teardown.sh