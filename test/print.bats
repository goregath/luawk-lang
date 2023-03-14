#!/usr/bin/env bash

# shellcheck shell=bats
# shellcheck disable=SC1091,SC2093,SC2164

if [[ -z "$BATS_TEST_DIRNAME" ]]; then
	exec "${0%/*}"/bats/bats-core/bin/bats --tap "$0" "$@"
fi

source "$BATS_TEST_DIRNAME"/bats/commons.bash

# shellcheck disable=SC2034
setup() {
	load 'bats/bats-support/load'
	load 'bats/bats-assert/load'
	load 'bats/bats-file/load'
	TEST_TMPDIR="$(temp_make --prefix 'luawk-')"
	BATSLIB_FILE_PATH_REM="#${TEST_TMPDIR}"
	BATSLIB_FILE_PATH_ADD='<temp>'
}

teardown() {
	temp_del "$TEST_TMPDIR"
}

# > expression
# >> expression
# | expression

@test "redirect and truncate" {
	skip "not implemented"
	local file="$TEST_TMPDIR"/out
	run luawk -vredirect="$file" 'BEGIN { print "lorem ipsum" > redirect }'
	assert_success
	assert_output ''
	assert_file_contains "$file" "^lorem ipsum$"
}

@test "redirect and append" {
	skip "not implemented"
}

@test "redirect to command" {
	skip "not implemented"
}