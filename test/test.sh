docker build -t remote-ffmpeg-mod .. && \
docker build -t remote-ffmpeg -f ./Dockerfile.test . && \
docker run \
    --env-file .env \
    -v ./config:/config/ \
    remote-ffmpeg /usr/bin/remote-ffmpeg $@