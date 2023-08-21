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

@test "global function in prolog" {
	run luawk -vOFS=, <<<"a b c d" '
		function shift(n = 0) {
			table.move($@, 1+n, #$@, 1)
			NF -= n
		}
		{ shift(2) }
		1
	'
	assert_output 'c,d'
}

@test "global function in BEGIN" {
	run luawk -vOFS=, <<<"a b c d" '
		BEGIN {
			shift = (n = 0) -> {
				table.move($@, 1+n, #$@, 1)
				NF -= n
			}
		}
		{ shift(2) }
		1
	'
	assert_output 'c,d'
}
