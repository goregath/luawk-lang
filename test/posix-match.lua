#!/bin/sh -e

if true --[[; then
	cd "${0%/*}/.."
	exec /usr/bin/env lua "test/${0##*/}" "$@"
fi; --]] then
	package.path = "lib/?.lua;lib/?/init.lua;test/lua/lib/?.lua;" .. package.path
end

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.environment.posix split()")

group:setup(function()
	return require "luawk.environment.posix".new()
end)

group:add('no match', function(R)
    local cap = { R.match("lorem ipsum dolor", "x") }
	assert_equal(cap[1], 0)
	assert_equal(cap[2], 0)
end)

group:add('on match start and end is returned', function(R)
    local cap = { R.match("lorem ipsum dolor", "i%w+") }
	assert_equal(cap[1], 7)
	assert_equal(cap[2], 11)
end)

group:add('result of match() fits string.sub() function signature', function(R)
    local str = "lorem ipsum dolor sit amet"
    assert_equal(str:sub(  R.match(str, "sit")  ),  "sit")
    assert_equal(str:sub(  R.match(str, "xxx")  ),  "")
    -- omitting the second return value (end) can be handy
    assert_equal(str:sub( (R.match(str, "sit")) ),  "sit amet")
    assert_equal(str:sub( (R.match(str, "xxx")) ),  "lorem ipsum dolor sit amet")
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
