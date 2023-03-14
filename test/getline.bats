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

@test "getline is a keyword" {
	skip "bug"
	run luawk '
		function getline(...)
			print("getline", select("#", ...), ...)
		end
		BEGIN { getline }
	'
	assert_success
	assert_output 'getline 0'
}

@test "read entire input in BEGIN" {
	skip "bug"
	run luawk '
		BEGIN {
			while getline do
				print
			end
		}
	' <<<$'line1\nline2'
	assert_success
	assert_output $'line1\nline2'
}