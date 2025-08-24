#!/usr/bin/bash

COMMON_RUNNER_ARGS=(
    --rm
    -v "$TEMP_SSH_DIR":/config/.ssh
)

ffmpeg_build_image() {
    variant=$1
    docker build -qt remote-ffmpeg-mod .. > /dev/null
    docker build -qt "remote-ffmpeg-$variant" -f "./images/Dockerfile.test-$variant" . > /dev/null
}

ffmpeg_create_runner() {
    variant=$1
    build_runner_image "$variant"
    docker run --name "remote-ffmpeg-$variant" \
        "${COMMON_RUNNER_ARGS[@]}" \
        "${RUNNER_ARGS[@]}" \
        "remote-ffmpeg-$variant" "${@:2}"
}

ffmpeg_create_daemon_runner() {
    variant=$1
    ffmpeg_build_image "$variant"
    name="forkable-remote-ffmpeg-$variant"
    docker run -d --name "$name" \
        "${COMMON_RUNNER_ARGS[@]}" \
        "${RUNNER_ARGS[@]}" \
        "remote-ffmpeg-$variant" bash -c "while [ ! -f ~/.exit ]; do sleep 1; done" > /dev/null
    until docker logs "$name" 2>&1 | grep -q '\[ls.io-init\] done.'; do
        sleep 1
    done
}

ffmpeg_daemon_exec() {
    variant=$1
    docker exec -t "forkable-remote-ffmpeg-$variant" "${@:2}"
}

ffmpeg_destroy_daemon_runner() {
    variant=$1
    ffmpeg_daemon_exec "$variant" bash -c "touch ~/.exit"
    docker stop "forkable-remote-ffmpeg-$variant" > /dev/null
}

ffmpeg_daemon_invoke() {
    variant=$1
    executable=$2
    ffmpeg_daemon_exec "$variant" /usr/bin/remote-ffmpeg/"$executable" "${@:3}"
}

ffmpeg_daemon_spawn() {
    variant=$1
    n=$2
    local -n o=$3
    executable=$4
    
    declare -a pids
    declare -a tmps

    ffmpeg_create_daemon_runner "$variant"

    for ((i=0; i<n; i++)); do
        tmp=$(mktemp)
        tmps[i]=$tmp

        ffmpeg_daemon_invoke "$variant" "$executable" "${@:5}" > "$tmp" 2>&1 &
        pids[i]=$!
    done

    for ((i=0; i<n; i++)); do
        wait "${pids[i]}"
        # shellcheck disable=SC2034
        o[i]=$( < "${tmps[i]}" )

        rm -f "${tmps[i]}"
    done

    ffmpeg_destroy_daemon_runner "$variant"
}

ffmpeg_invoke() {
    variant=$1
    executable=$2
    ffmpeg_create_runner "$variant" /usr/bin/remote-ffmpeg/"$executable" "${@:3}"
}

ffmpeg_md5() {
    sed -n 's/.*MD5=\([a-fA-F0-9]\{32\}\).*/\1/p'
}