#!/usr/bin/bash

COMMON_RUNNER_ARGS=(
    --rm
    -v "$TEMP_SSH_DIR":/config/.ssh
)

build_runner_image() {
    variant=$1
    docker build -qt remote-ffmpeg-mod .. > /dev/null
    docker build -qt "remote-ffmpeg-$variant" -f "./images/Dockerfile.test-$variant" . > /dev/null
}

create_runner() {
    variant=$1
    build_runner_image "$variant"
    docker run --name "remote-ffmpeg-$variant" \
        "${COMMON_RUNNER_ARGS[@]}" \
        "${RUNNER_ARGS[@]}" \
        "remote-ffmpeg-$variant" "${@:2}"
}

create_runner_forkable() {
    variant=$1
    build_runner_image "$variant"
    name="forkable-remote-ffmpeg-$variant"
    docker run -d --name "$name" \
        "${COMMON_RUNNER_ARGS[@]}" \
        "${RUNNER_ARGS[@]}" \
        "remote-ffmpeg-$variant" bash -c "while [ ! -f ~/.exit ]; do sleep 1; done" > /dev/null
    until docker logs "$name" 2>&1 | grep -q '\[ls.io-init\] done.'; do
        sleep 1
    done
}

forkable_runner_exec() {
    variant=$1
    docker exec -t "forkable-remote-ffmpeg-$variant" "${@:2}"
}

destroy_runner_forkable() {
    variant=$1
    forkable_runner_exec "$variant" bash -c "touch ~/.exit"
    docker stop "forkable-remote-ffmpeg-$variant" > /dev/null
}

fork_n_times() {
    variant=$1
    n=$2
    local -n o=$3
    func=$4
    
    declare -a pids
    declare -a tmps

    create_runner_forkable "$variant"

    for ((i=0; i<n; i++)); do
        tmp=$(mktemp)
        tmps[i]=$tmp

        $func "${@:5}" > "$tmp" 2>&1 &
        sleep 2
        pids[i]=$!
    done

    for ((i=0; i<n; i++)); do
        wait "${pids[i]}"
        # shellcheck disable=SC2034
        o[i]=$( < "${tmps[i]}" )

        rm -f "${tmps[i]}"
    done

    destroy_runner_forkable "$variant"
}

fork_n_times_ubuntu() {
    n=$1
    output=$2
    func=$3
    fork_n_times "ubuntu" "$n" "$output" "$func" "${@:4}"
}

fork_n_times_alpine() {
    n=$1
    output=$2
    func=$3
    fork_n_times "alpine" "$n" "$output" "$func" "${@:4}"
}

remote_ffmpeg() {
    variant=$1
    executable=$2
    create_runner "$variant" /usr/bin/remote-ffmpeg/"$executable" "${@:3}"
}

f_remote_ffmpeg() {
    variant=$1
    executable=$2
    forkable_runner_exec "$variant" /usr/bin/remote-ffmpeg/"$executable" "${@:3}"
}

remote_ffmpeg_ubuntu() {
    remote_ffmpeg "ubuntu" "ffmpeg" "$@"
}

f_remote_ffmpeg_ubuntu() {
    f_remote_ffmpeg "ubuntu" "ffmpeg" "$@"
}

remote_ffmpeg_alpine() {
    remote_ffmpeg "alpine" "ffmpeg" "$@"
}

f_remote_ffmpeg_alpine() {
    f_remote_ffmpeg "alpine" "ffmpeg" "$@"
}

remote_ffprobe_ubuntu() {
    remote_ffmpeg "ubuntu" "ffprobe" "$@"
}

f_remote_ffprobe_ubuntu() {
    f_remote_ffmpeg "ubuntu" "ffprobe" "$@"
}

remote_ffprobe_alpine() {
    remote_ffmpeg "alpine" "ffprobe" "$@"
}

f_remote_ffprobe_alpine() {
    f_remote_ffmpeg "alpine" "ffprobe" "$@"
}
