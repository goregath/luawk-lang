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

@test "FILENAME is undefined in BEGIN" {
	run luawk 'BEGIN { print type(FILENAME) }'
	assert_success
	assert_output 'nil'
}

@test "NF is zero in BEGIN" {
	run luawk 'BEGIN { print type(NF), NF }'
	assert_success
	assert_output 'number 0'
}

@test "NF is retained in END" {
	run luawk 'END { print NF }' <<-"AWK"
		a
		a b
		a b c
	AWK
	assert_success
	assert_output '3'
}

@test "NR is zero in BEGIN" {
	run luawk 'BEGIN { print type(NR), NR }'
	assert_success
	assert_output 'number 0'
}

@test "NR is number of last processed record in END" {
	run luawk 'END { print type(NR), NR }' \
		/dev/fd/3 3<<<$'a\nb\nc' \
		/dev/fd/4 4<<<$'d\ne\nf\ng'
	assert_success
	assert_output 'number 7'
}

@test "FNR is zero in BEGIN" {
	run luawk 'BEGIN { print type(FNR), FNR }'
	assert_success
	assert_output 'number 0'
}

@test "FNR is number of last processed record in the last file END" {
	run luawk 'END { print type(FNR), FNR }' \
		/dev/fd/3 3<<<$'a\nb\nc' \
		/dev/fd/4 4<<<$'d\ne\nf\ng'
	assert_success
	assert_output 'number 4'
}

@test "test for correct order" {
	run luawk '
		ENDFILE   { print "ENDFILE" }
		END       { print "END" }
		BEGIN     { print "BEGIN" }
		BEGINFILE { print "BEGINFILE" }
		1
	' \
		/dev/fd/3 3<<<$'a b c' \
		/dev/fd/4 4<<<$'d e f'
	
	assert_output - <<-"ASSERT"
		BEGIN
		BEGINFILE
		a b c
		ENDFILE
		BEGINFILE
		d e f
		ENDFILE
		END
	ASSERT
}

@test "exclusive BEGIN does not process input" {
	run luawk 'BEGIN {}'
	assert_success
}

@test "exclusive END processes files without action" {
	run luawk 'END { print FNR, NR }' \
		/dev/fd/3 3<<<$'a\nb\nc' \
		/dev/fd/4 4<<<$'d\ne\nf'
	assert_success
	assert_output '3 6'
}

@test "exclusive ENFDILE processes files without action" {
	run luawk 'ENDFILE { print FNR, NR }' \
		/dev/fd/3 3<<<$'a\nb\nc' \
		/dev/fd/4 4<<<$'d\ne\nf'
	assert_success
	assert_output - <<-"ASSERT"
		3 3
		3 6
	ASSERT
}