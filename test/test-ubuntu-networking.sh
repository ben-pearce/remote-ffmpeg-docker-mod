#!/usr/bin/bash

. ./test-startup.sh

docker build -t remote-ffmpeg -f ./Dockerfile.test-ubuntu . && \
docker run --network=remote-ffmpeg-network --name remote-ffmpeg-nginx -v ./www:/usr/share/nginx/html -d nginx && \
docker run \
    -it \
    --name remote-ffmpeg \
    --network=remote-ffmpeg-network \
    -e "REMOTE_FFMPEG_USER=ubuntu" \
    -e "REMOTE_FFMPEG_HOST=renderer" \
    -e "REMOTE_FFMPEG_PORT=6543" \
    -e "REMOTE_FFMPEG_FORWARD_HOSTS=8080:remote-ffmpeg-nginx:80" \
    -v $TEMP_SSH_DIR:/config/.ssh \
    remote-ffmpeg /usr/bin/remote-ffmpeg/ffmpeg -i http://remote-ffmpeg-nginx:8080/demo.mp4 -c:v libx264 -c:a aac -f null /dev/null
docker stop remote-ffmpeg-nginx
docker rm -f remote-ffmpeg remote-ffmpeg-nginx

./test-teardown.sh