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
	
	assert_output - <<-"EXP"
		BEGIN
		BEGINFILE
		a b c
		ENDFILE
		BEGINFILE
		d e f
		ENDFILE
		END
	EXP
}