#!/usr/bin/bash

RUNNER_ARGS=(
    --network=remote-ffmpeg-network
    -e "REMOTE_FFMPEG_USER=ubuntu"
    -e "REMOTE_FFMPEG_HOST=renderer"
    -e "REMOTE_FFMPEG_PORT=6543"
)

. ./common/environment.sh
. ./common/ffmpeg.sh

setup_suite() {
    setup_apparmor_restrictions
    setup_renderer_mock
}

test_assert_alpine_ffmpeg_has_banner() {
    banner="Hyper fast Audio and Video encoder"
    assert_equals "$banner" "$( ffmpeg_invoke "alpine" "ffmpeg" -h 2>&1 | grep "$banner" )"
}

test_assert_alpine_ffprobe_has_banner() {
    banner="Simple multimedia streams analyzer"
    assert_equals "$banner" "$( ffmpeg_invoke "alpine" "ffprobe" -h 2>&1 | grep "$banner" )"
}

test_assert_ubuntu_ffmpeg_has_banner() {
    banner="Hyper fast Audio and Video encoder"
    assert_equals "$banner" "$( ffmpeg_invoke "ubuntu" "ffmpeg" -h 2>&1 | grep "$banner" )"
}

test_assert_ubuntu_ffprobe_has_banner() {
    banner="Simple multimedia streams analyzer"
    assert_equals "$banner" "$( ffmpeg_invoke "ubuntu" "ffprobe" -h 2>&1 | grep "$banner" )"
}

teardown_suite() {
    teardown_renderer_mock
    teardown_apparmor_restrictions
}