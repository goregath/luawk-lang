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

@test "single match" {
	run luawk '/^+/,/^-/' <<-"AWK"
		line1
		line2
		+++++
		line3
		line4
		-----
		line5
		line6
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		+++++
		line3
		line4
		-----
	ASSERT
}

@test "repeated match" {
	run luawk '/^+/,/^-/' <<-"AWK"
		line1
		line2
		+++++
		line3
		line4
		-----
		line5
		line6
		+++++
		line7
		line8
		-----
		line9
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		+++++
		line3
		line4
		-----
		+++++
		line7
		line8
		-----
	ASSERT
}

@test "match not closed" {
	run luawk '/^+/,/^-/' <<-"AWK"
		line1
		line2
		+++++
		line3
		line4
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		+++++
		line3
		line4
	ASSERT
}

@test "no match" {
	run luawk '/^+/,/^-/' <<-"AWK"
		line1
		line2
		-----
		line3
		line4
	AWK
	assert_success
	assert_output ""
}

@test "proper match on open close" {
	run luawk '/^+/,/^-/' <<-"AWK"
		line1
		line2
		+++++
		+++++
		line3
		line4
		-----
		-----
		line5
		line6
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		+++++
		+++++
		line3
		line4
		-----
	ASSERT
}

@test "constant begin pattern" {
	run luawk '1,/^-/' <<-"AWK"
		line1
		line2
		+++++
		line3
		line4
		-----
		line5
		line6
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		line1
		line2
		+++++
		line3
		line4
		-----
		line5
		line6
	ASSERT
}

@test "constant end pattern" {
	run luawk '/^+/,1' <<-"AWK"
		line1
		line2
		+++++
		line3
		line4
		-----
		line5
		line6
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		+++++
	ASSERT
}

@test "range continues on next file" {
	run luawk 'BEGINFILE { print FILENAME } /^+/,/^-/' /dev/fd/{3,4} 3<<-"FILE1" 4<<-"FILE2"
		line1
		line2
		+++++
		line3
	FILE1
		line4
		-----
		line5
		line6
	FILE2
	assert_success
	assert_output - <<-"ASSERT"
		/dev/fd/3
		+++++
		line3
		/dev/fd/4
		line4
		-----
	ASSERT
}