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

@test "split by colon" {
	run luawk -F: '{ print($2) }' <<<$'a:b:c'
	assert_output 'b'
}

@test "print last field" {
	run luawk '{ print($NF) }' <<<$'a b c'
	assert_output 'c'
}

@test "unset second field and print" {
	run luawk -vOFS=, '{ $2=nil } 1' <<<$'a b c'
	assert_output 'a,,c'
}

@test "table.remove second field and print" {
	run luawk -vOFS=, '{ table.remove($@, 2) } 1' <<<$'a b c'
	assert_output 'a,c,'
}

@test "table.sort fields and print" {
	run luawk '{ table.sort($@) } 1' <<<$'lorem ipsum dolor'
	assert_output 'dolor ipsum lorem'
}

@test "table.sort fields in reverse and print" {
	run luawk '{ table.sort($@,(l,r)->(l>r)) } 1' <<<$'sit amet dolor'
	assert_output 'sit dolor amet'
}

@test "swap fields and print" {
	run luawk -vOFS=, '{ $2,$1 = $1,$2 } 1' <<<$'a b c'
	assert_output 'b,a,c'
}

@test "add first two fields, set to third field and print" {
	run luawk -vOFS=, '{ $3 = $1+$2 } 1' <<<$'13 29'
	assert_output '13,29,42'
}

@test "add field and print (awk style)" {
	run luawk -vOFS=, '{ $(NF+1) = "x" } 1' <<<$'a b c'
	assert_output 'a,b,c,x'
}

@test "add field and print (luawk style)" {
	run luawk -vOFS=, '{ $@ += "x" } 1' <<<$'a b c'
	assert_output 'a,b,c,x'
}

@test "bulk add fields and print" {
	run luawk -vOFS=, '{ $@ += { 1,2,3 } } 1' <<<$'a b c'
	assert_output 'a,b,c,1,2,3'
}

@test "bulk add '\$@' to itself and print" {
	run luawk -vOFS=, '{ $@ += $@ } 1' <<<$'a b c'
	assert_output 'a,b,c,a,b,c'
}

@test "assignment in parameter list" {
	run luawk '{ print(NF) }' /dev/fd/3 FS=, /dev/fd/4 \
		3<<<'a b c' \
		4<<<'a,b,c'
	assert_output - <<-"ASSERT"
		3
		3
	ASSERT
}

@test "null-terminated records" {
	run luawk -vOFS=, 'BEGIN { RS="\0" } { NF=NF } 1' <(printf 'a b c\0d e f')
	assert_line -n 0 'a,b,c'
	assert_line -n 1 'd,e,f'
}
