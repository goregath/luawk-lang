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

@test "nextfile" {
	run luawk '{ nextfile }' /etc/passwd
	assert_success
	assert_output ''
}

@test "nextfile (BEGIN)" {
	run luawk 'BEGIN { nextfile }'
	assert_failure
}

@test "nextfile (END)" {
	run luawk 'END { nextfile }' /dev/null
	assert_failure
}

@test "nextfile (BEGINFILE)" {
	run luawk 'BEGINFILE { nextfile }'
	assert_failure
}

@test "nextfile (ENDFILE)" {
	run luawk 'ENDFILE { nextfile }' /dev/null
	assert_failure
}

@test "nextfile skips actions" {
	run luawk '1; { nextfile } { print "unreachable" }' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
	ASSERT
}