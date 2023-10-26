#!/bin/bash

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

@test "empty arguments list defaults to stdin" {
    run luawk -vOFS=, 'BEGINFILE { print FILENAME,ARGC,ARGIND; exit }'
	assert_output '-,1,0'
}

@test "arguments rodeo" {
	run luawk -Fx -vOFS=, 'BEGINFILE { print FS,FILENAME,ARGC,ARGIND,ARGV[ARGIND] }' '' /dev/null FS=y '' /dev/null
	assert_line -n 0 'x,/dev/null,6,2,/dev/null'
	assert_line -n 1 'y,/dev/null,6,5,/dev/null'
}

