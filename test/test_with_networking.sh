#!/usr/bin/bash

RUNNER_ARGS=(
    --network=remote-ffmpeg-network
    -e "REMOTE_FFMPEG_USER=ubuntu"
    -e "REMOTE_FFMPEG_HOST=renderer"
    -e "REMOTE_FFMPEG_PORT=6543"
    -e "REMOTE_FFMPEG_FORWARD_HOSTS=8080:remote-ffmpeg-nginx:80"
    -v ./www:/test
)

INPUT_FILE=http://remote-ffmpeg-nginx:8080/demo.mp4

FFMPEG_ARGS=(
    -i "$INPUT_FILE"
    -c:v copy
    -c:a copy
    -f md5 -
)

EXPECTED_SUM="a75a1c0f557466006ac98ee01f34ab07"

. ./common/suite.sh
. ./common/ffmpeg.sh

setup_suite() {
    relax_apparmor_restrictions
    create_renderer_mock
    create_proxy_mock
}

extract_md5() {
    sed -n 's/.*MD5=\([a-fA-F0-9]\{32\}\).*/\1/p'
}

test_assert_alpine_conv_expected_output() {
    sum=$( remote_ffmpeg_alpine "${FFMPEG_ARGS[@]}" 2>&1 | extract_md5 )
    assert_equals "$EXPECTED_SUM" "$sum"
}

test_assert_alpine_conv_expected_output_multiple() {
    declare -a outputs
    fork_n_times_alpine 3 outputs f_remote_ffmpeg_alpine "${FFMPEG_ARGS[@]}"

    for o in "${outputs[@]}"; do
        assert_equals "$EXPECTED_SUM" "$(extract_md5 <<< "$o")"
    done
}

test_assert_ubuntu_conv_expected_output() {
    sum=$(remote_ffmpeg_ubuntu "${FFMPEG_ARGS[@]}" 2>&1 | extract_md5 )
    assert_equals "$EXPECTED_SUM" "$sum"
}

test_assert_ubuntu_conv_expected_output_multiple() {
    declare -a outputs
    fork_n_times_ubuntu 3 outputs f_remote_ffmpeg_ubuntu "${FFMPEG_ARGS[@]}"

    for o in "${outputs[@]}"; do
        assert_equals "$EXPECTED_SUM" "$(extract_md5 <<< "$o")"
    done
}

teardown_suite() {
    destroy_proxy_mock
    destroy_renderer_mock
    tighten_apparmor_restrictions
}