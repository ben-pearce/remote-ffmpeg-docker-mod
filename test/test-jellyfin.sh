docker build -t remote-ffmpeg-mod .. && \
docker build -t remote-ffmpeg-jellyfin -f ./Dockerfile.test-jellyfin . && \
docker run -d \
    --name remote-ffmpeg-jellyfin \
    --env-file .env \
    --env REMOTE_FFMPEG_BINARY=/usr/lib/jellyfin-ffmpeg/ffmpeg \
    --env FFMPEG_PATH=/usr/bin/remote-ffmpeg \
    --env PUID=1000 \
    --env PGID=1000 \
    --env TZ=Europe/London \
    -v ./config:/config/ \
    -v ./config/tvseries:/data/tvshows \
    -v ./config/movies:/data/movies \
    remote-ffmpeg-jellyfin
while ! docker logs remote-ffmpeg-jellyfin | grep -q "Main: Startup complete" ; do sleep 1; done
docker exec -it -u abc remote-ffmpeg-jellyfin /usr/bin/remote-ffmpeg
docker stop remote-ffmpeg-jellyfin
docker rm -f remote-ffmpeg-jellyfin