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

@test "assinment in parameter list" {
	run luawk '{ print NF }' /dev/fd/3 FS=, /dev/fd/4 \
		3<<<'a b c' \
		4<<<'a,b,c'
	assert_output - <<-"ASSERT"
		3
		3
	ASSERT
}
