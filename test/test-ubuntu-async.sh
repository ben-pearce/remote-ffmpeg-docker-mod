docker network create --driver bridge remote-ffmpeg-network
docker build -t remote-ffmpeg-mod .. && \
docker build -t remote-ffmpeg -f ./Dockerfile.test-ubuntu . && \
docker run --network=remote-ffmpeg-network --name remote-ffmpeg-nginx -v ./www:/usr/share/nginx/html -d nginx && \
docker run \
    -d \
    --name remote-ffmpeg \
    --network=remote-ffmpeg-network \
    --env-file .env \
    -v ./config:/config/ \
    remote-ffmpeg /usr/bin/bash -c "while [ ! -f ~/.exit ]; do sleep 1; done"
sleep 1
docker exec remote-ffmpeg /usr/bin/remote-ffmpeg -i http://remote-ffmpeg-nginx:8080/demo.mp4 -c:v libx264 -c:a aac -f null /dev/null &
docker exec -it remote-ffmpeg /usr/bin/remote-ffmpeg -i http://remote-ffmpeg-nginx:8080/demo.mp4 -c:v libx264 -c:a aac -f null /dev/null
sleep 5
docker exec -it remote-ffmpeg top -n 1
docker exec -it remote-ffmpeg /usr/bin/bash -c "touch ~/.exit"
docker stop remote-ffmpeg remote-ffmpeg-nginx
docker rm -f remote-ffmpeg remote-ffmpeg-nginx
docker network rm remote-ffmpeg-network