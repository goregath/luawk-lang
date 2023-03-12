#!/bin/bash

# shellcheck shell=bats
# shellcheck disable=SC2093,SC2164,SC2155

if ! type load run skip 1>/dev/null 2>&1; then
	exec "${0%/*}"/bats/bats-core/bin/bats --tap "$0" "$@"
fi

luawk() {
	../src/luawk.lua "$@"
}

setup() {
	load 'bats/bats-support/load'
	load 'bats/bats-assert/load'
	cd "$BATS_TEST_DIRNAME"
	export BATS_TEST_TIMEOUT=1
	export LUA_PATH="../src/?.lua;$(lua -e 'print(package.path)')"
}

@test "print last field" {
	run luawk '{ print $NF }' <<<$'a b c'
	assert_output 'c'
}

@test "delete second field and print" {
	run luawk '{ $2="" } 1' <<<$'a b c'
	assert_output 'a  c'
}

@test "split by colon" {
	run luawk -F: '{ print $2 }' <<<$'a:b:c'
	assert_output 'b'
}