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

@test "echo" {
	run luawk '1' <<<$'a b c'
	assert_output 'a b c'
}

@test "no action" {
	run luawk '' /etc/passwd
	assert_output ''
}

@test "special actions (test for correct order)" {
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

@test "begin action only (no loop)" {
	run luawk 'BEGIN {}' /etc/passwd
	assert_output ''
}

@test "end action only (no loop)" {
	run luawk 'END {}' /etc/passwd
	assert_output ''
}