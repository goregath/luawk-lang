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

@test "regex pattern" {
	run luawk '/^line%d+/' <<<$'line1\nline2'
	assert_success
	assert_output $'line1\nline2'
}

@test "regex pattern chain" {
	run luawk '/^.n:/ and not /^d/' <<-"AWK"
		dn: cn=John Doe,dc=example,dc=com
		cn: John Doe
		sn: Doe
		mail: john@example.com
		objectClass: inetOrgPerson
	AWK
	assert_success
	assert_output - <<-"ASSERT"
		cn: John Doe
		sn: Doe
	ASSERT
}

@test "pattern only defaults to print action" {
	run luawk 'true' <<<$'line1\nline2'
	assert_success
	assert_output $'line1\nline2'
}

@test "skip action if pattern evaluates to false" {
	run luawk '
		false { print "unreachable" }
		nil   { print "unreachable" }
	' <<<$'line1\nline2'
	assert_success
	assert_output ''
}