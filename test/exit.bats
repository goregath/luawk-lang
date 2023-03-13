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

@test "exit" {
	run luawk 'BEGIN { exit }' /etc/passwd
	assert_success
}

@test "exit(1)" {
	run luawk 'BEGIN { exit 1 }' /etc/passwd
	assert_failure
}

@test "exit(99)" {
	run luawk 'BEGIN { exit 99 }' /etc/passwd
	assert_failure 99
}

@test "exit(-1)" {
	run luawk 'BEGIN { exit -1 }' /etc/passwd
	assert_failure 255
}

@test "exit returns from action" {
	run luawk '1; { exit; print "unreachable" } END { print "END" }' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		END
	ASSERT
}

@test "exit skips subsequent actions" {
	run luawk '1; { exit } { print "unreachable" } END { print "END" }' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		END
	ASSERT
}

@test "exit jumps to END" {
	run luawk '
		1;
		{ exit }
		{ print "unreachable" }
		ENDFILE { print "unreachable" }
		END { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		END
	ASSERT
}

@test "exit called again in END without status" {
	run luawk 'BEGIN { exit 99 } END { exit }' /etc/passwd
	assert_failure 99
}

@test "exit called again in END with status" {
	run luawk 'BEGIN { exit 99 } END { exit 0 }' /etc/passwd
	assert_success
}