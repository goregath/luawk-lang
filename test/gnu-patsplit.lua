#!/bin/sh -e

if true --[[; then
	cd "${0%/*}/.."
	exec /usr/bin/env lua "test/${0##*/}" "$@"
fi; --]] then
	package.path = "lib/?.lua;lib/?/init.lua;test/lua/lib/?.lua;" .. package.path
end

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.environment.gnu patsplit()")

group:setup(function()
	return require "luawk.environment.gnu".new()
end)

group:add("fallback to FPAT", function(R)
	local a = {}
	R.FPAT = "%w+"
	assert_equal(R.patsplit("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add("extract words", function(R)
	local a = {}
	assert_equal(R.patsplit("lorem-ipsum, dolor sit amet", a, "[%w-]+"), 4)
	assert_equal(table.concat(a, ","), "lorem-ipsum,dolor,sit,amet")
end)

group:add("dead beef", function(R)
	local a, s = {}, {}
	local n = R.patsplit("0xDEAD, 0xBEEF", a, "%x%x", s)
	assert_equal(n, 4)
	assert_equal(#a, 4)
	assert_equal(#s, 4)
	assert_equal(s[0], "0x")
	assert_equal(a[1], "DE")
	assert_equal(s[1], "")
	assert_equal(a[2], "AD")
	assert_equal(s[2], ", 0x")
	assert_equal(a[3], "BE")
	assert_equal(s[3], "")
	assert_equal(a[4], "EF")
	assert_equal(s[4], "")
end)

group:add("split path", function(R)
	local a = {}
	assert_equal(R.patsplit("/etc//passwd/", a, "[^/]+"), 2)
	assert_equal(table.concat(a, ","), "etc,passwd")
end)

group:add("trailing case", function(R)
	local a, s = {}, {}
	local n = R.patsplit("bbbaaacccdddaaaaaqqqqa", a, "aa+", s)
	assert_equal(n, 2)
	assert_equal(#a, 2)
	assert_equal(#s, 2)
	assert_equal(s[0], "bbb")
	assert_equal(a[1], "aaa")
	assert_equal(s[1], "cccddd")
	assert_equal(a[2], "aaaaa")
	assert_equal(s[2], "qqqqa")
end)

group:run()