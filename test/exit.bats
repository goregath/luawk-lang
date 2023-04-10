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

@test "exit(2.5)" {
	run luawk 'BEGIN { exit 2.5 }' /etc/passwd
	assert_failure 2
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

@test "exit in BEGIN" {
	run luawk '
		BEGIN     { exit 1; print "unreachable" }
		BEGIN     { print "unreachable" }
		BEGINFILE { print "unreachable" }
		1         { print "unreachable" }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		END
	ASSERT
}

@test "exit in BEGINFILE" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { exit 1; print "unreachable" }
		1         { print "unreachable" }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		END
	ASSERT
}

@test "exit in action" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { exit 1; print "unreachable" }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		END
	ASSERT
}

@test "exit in ENDILE" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { print "ACTION" }
		ENDFILE   { exit 1; print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		ACTION
		ACTION
		END
	ASSERT
}

@test "exit in END" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { print "ACTION" }
		ENDFILE   { print "ENDFILE" }
		END       { exit 1; print "unreachable" }
		END       { print "unreachable" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		ACTION
		ACTION
		ENDFILE
	ASSERT
}

@test "return in BEGIN" {
	run luawk '
		BEGIN     { return 1 }
		BEGIN     { print "unreachable" }
		BEGINFILE { print "unreachable" }
		1         { print "unreachable" }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		END
	ASSERT
}

@test "return in BEGINFILE" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { return 1 }
		1         { print "unreachable" }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		END
	ASSERT
}

@test "return in action" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { return 1 }
		ENDFILE   { print "unreachable" }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		END
	ASSERT
}

@test "return in ENDILE" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { print "ACTION" }
		ENDFILE   { return 1 }
		END       { print "END" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		ACTION
		ACTION
		END
	ASSERT
}

@test "return in END" {
	run luawk '
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1         { print "ACTION" }
		ENDFILE   { print "ENDFILE" }
		END       { return 1 }
		END       { print "unreachable" }
	' <<-"AWK"
		line1
		line2
	AWK
	assert_failure
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		ACTION
		ACTION
		ENDFILE
	ASSERT
}