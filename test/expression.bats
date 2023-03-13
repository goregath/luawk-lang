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

@test "regex expression" {
	# evaluated to 'match($0,"b")'
	run luawk '{ print /b/ }' <<<"a b c"
	assert_success
	assert_output '3'
}

@test "match operator" {
	run luawk 'BEGIN {
		if "deadbeef" ~ /^[0-9a-f]+$/ then
			print "match"
		end
		if "deadbeef" ~ "^[0-9a-f]+$" then
			print "match"
		end
		if not "" ~ /^[0-9a-f]+$/ then
			print "nomatch"
		end
	}'
	assert_success
	assert_output - <<-"ASSERT"
		match
		match
		nomatch
	ASSERT
}

@test "match operator chain" {
	# evaluated to 'match(match($0,"b"),3)'
	run luawk '$0 ~ /b/ ~ 3 { print }' <<<"a b c"
	assert_success
	assert_output "a b c"
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