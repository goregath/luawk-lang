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
	run luawk '
		BEGIN {
			while getline() do
				print
			end
		}
	' <<<$'line1\nline2'
	assert_success
	assert_output $'line1\nline2'
}

@test "getline loop in BEGIN calls BEGINFILE and ENDFILE" {
	skip "bug"
	run luawk '
		BEGIN     { while getline do print end }
		BEGINFILE { print "BEGINFILE", FILENAME }
		ENDFILE   { print "ENDFILE", FILENAME }
	' /dev/fd/3 /dev/fd/4 \
		3<<<'file1' \
		4<<<'file2'
	assert_success
	assert_output - <<-"ASSERT"
		BEGINFILE /dev/fd/3
		file1
		ENDFILE /dev/fd/3
		BEGINFILE /dev/fd/4
		file2
		ENDFILE /dev/fd/4
	ASSERT
}

@test "getline in BEGIN" {
	run luawk '
		BEGIN { getline }
		BEGIN { print "BEGIN" }
		END   { print "END" }
	' /dev/null
	assert_success
	assert_output - <<-"ASSERT"
		BEGIN
		END
	ASSERT
}

@test "getline in END" {
	run luawk '
		END { getline }
		END { print "END" }
	' /dev/null
	assert_success
	assert_output - <<-"ASSERT"
		END
	ASSERT
}

@test "getline in BEGINFILE" {
	run luawk '
		BEGINFILE { getline }
	' /dev/null
	assert_failure
}

@test "getline in ENDFILE" {
	run luawk '
		ENDFILE { getline }
	' /dev/null
	assert_failure
}

@test "getline in action" {
	run luawk '
		{ getline }
		{ print "action" }
	' <<<$'line1'
	assert_success
	assert_output - <<-"ASSERT"
		action
	ASSERT
}

@test "pipe into getline" {
	skip "not implemented"
	#  expression | getline [var]
}


# TODO Inside the BEGINFILE rule, the value of ERRNO will be the empty string if
# the file was opened successfully.  Otherwise, there is some problem with the
# file and the code should use nextfile to skip it. If that is not done, gawk
# produces its usual fatal error for files that cannot be opened.

@test "ERRNO in BEGINFILE" {
	skip "not implemented"
}