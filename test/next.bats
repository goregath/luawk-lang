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

@test "next" {
	run luawk '{ next }' /etc/passwd
	assert_success
	assert_output ''
}

@test "next (BEGIN)" {
	run luawk 'BEGIN { next }'
	assert_failure
}

@test "next (END)" {
	run luawk 'END { next }' /dev/null
	assert_failure
}

@test "next (BEGINFILE)" {
	run luawk 'BEGINFILE { next }' /dev/null
	assert_failure
}

@test "next (ENDFILE)" {
	run luawk 'ENDFILE { next }' /dev/null
	assert_failure
}

@test "next returns from action" {
	run luawk '{ print; next; print "unreachable" }' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		line2
	ASSERT
}

@test "next skips subsequent actions" {
	run luawk '1; { next } { print "unreachable" }' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		line2
	ASSERT
}