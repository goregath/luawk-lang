#!/bin/bash
# shellcheck shell=bats
# shellcheck disable=SC2093,SC2164
if ! type load run skip 1>/dev/null 2>&1; then
	exec "${0%/*}"/bats/bats-core/bin/bats --tap "$0" "$@"
fi

setup() {
	cd "$BATS_TEST_DIRNAME"
	LUA_PATH="$(lua -e 'print(package.path)')"
	LUA_PATH="../src/?.lua;$LUA_PATH"
	export LUA_PATH
	load 'bats/bats-support/load'
	load 'bats/bats-assert/load'
}

luawk() {
	../src/luawk.lua "$@"
}

@test "echo" {
	run luawk '1' <<<$'a b c'
	assert_output 'a b c'
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