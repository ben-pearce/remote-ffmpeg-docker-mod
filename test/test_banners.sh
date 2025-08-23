#!/usr/bin/bash

RUNNER_ARGS=(
    --network=remote-ffmpeg-network
    -e "REMOTE_FFMPEG_USER=ubuntu"
    -e "REMOTE_FFMPEG_HOST=renderer"
    -e "REMOTE_FFMPEG_PORT=6543"
)

. ./common/suite.sh
. ./common/ffmpeg.sh

setup_suite() {
    relax_apparmor_restrictions
    create_renderer_mock
}

test_assert_alpine_ffmpeg_has_banner() {
    banner="Hyper fast Audio and Video encoder"
    assert_equals "$banner" "$( remote_ffmpeg_alpine 2>&1 | grep "$banner" )"
}

test_assert_alpine_ffprobe_has_banner() {
    banner="Simple multimedia streams analyzer"
    assert_equals "$banner" "$( remote_ffprobe_alpine 2>&1 | grep "$banner" )"
}

test_assert_ubuntu_ffmpeg_has_banner() {
    banner="Hyper fast Audio and Video encoder"
    assert_equals "$banner" "$( remote_ffmpeg_ubuntu 2>&1 | grep "$banner" )"
}

test_assert_ubuntu_ffprobe_has_banner() {
    banner="Simple multimedia streams analyzer"
    assert_equals "$banner" "$( remote_ffprobe_ubuntu 2>&1 | grep "$banner" )"
}

teardown_suite() {
    destroy_renderer_mock
    tighten_apparmor_restrictions
}