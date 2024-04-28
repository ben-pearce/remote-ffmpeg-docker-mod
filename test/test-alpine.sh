docker build -t remote-ffmpeg-mod .. && \
docker build -t remote-ffmpeg -f ./Dockerfile.test-alpine . && \
docker run \
    --env-file .env \
    -v ./config:/config/ \
    remote-ffmpeg /usr/bin/remote-ffmpeg $@