#!/usr/bin/env bash

# shellcheck shell=bats
# shellcheck disable=SC1091,SC2093,SC2164

if [[ -z "$BATS_TEST_DIRNAME" ]]; then
	exec "${0%/*}"/bats/bats-core/bin/bats --tap "$0" "$@"
fi

source "$BATS_TEST_DIRNAME"/bats/commons.bash

setup() {
	load 'bats/bats-support/load'
	load 'bats/bats-assert/load'
}

@test "nil is empty string" {
	run luawk 'BEGIN { print x 1 }'
	assert_output '1'
}

@test "empty pattern is evaluates to \"1\" (always matches)" {
	run luawk 'BEGIN { print // 1 }'
	assert_output '11'
}
