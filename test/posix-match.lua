#!/bin/sh -e

if true --[[; then
	cd "${0%%/*}/.."
	exec /usr/bin/env lua -lluacov "test/${0##*/}" "$@"
fi; --]] then
	package.path = "src/?.lua;test/?.lua;test/lua/lib/?.lua;" .. package.path
end

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.environment.posix split()")

group:setup(function()
	return require "luawk.environment.posix".new()
end)

group:add('RSTART', function(R)
	assert_equal(R.RSTART, 0)
	assert_equal(R.match("a b c", "b"), 3)
	assert_equal(R.RSTART, 3)
end)

group:add('RLENGTH', function(R)
	assert_equal(R.RLENGTH, 0)
	assert_equal(R.match("a b c", ".*"), 1)
	assert_equal(R.RLENGTH, 5)
end)

group:run()