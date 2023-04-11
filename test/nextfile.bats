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
	run luawk 'BEGINFILE { nextfile }' /dev/null
	assert_success
}

@test "nextfile (ENDFILE)" {
	run luawk 'ENDFILE { nextfile }' /dev/null
	assert_failure
}

@test "nextfile skips actions" {
	run luawk '1; { nextfile } { print "unreachable" }' \
		/dev/fd/3 3<<<$'line1\nline2' \
		/dev/fd/4 4<<<$'line3\nline4'
	assert_success
	assert_output - <<-"ASSERT"
		line1
		line3
	ASSERT
}

@test "nextfile after first line" {
	run luawk 'FNR==2 { nextfile } 1' \
		/dev/fd/3 3<<<$'line1\nline2' \
		/dev/fd/4 4<<<$'line3\nline4'
	assert_success
	assert_output - <<-"ASSERT"
		line1
		line3
	ASSERT
}