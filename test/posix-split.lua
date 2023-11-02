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

group:add('defaults to FS="\\x20"', function(R)
	local a = {}
	assert_equal(R.FS, "\32")
	assert_equal(R.split("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add('special pattern of "\\x20" automatically trims leading and trailingspaces', function(R)
	local a = {}
	assert_equal(R.split("  a b c  ", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add('special pattern of "\\x20" automatically aggregate spaces', function(R)
	local a = {}
	assert_equal(R.split("a  b  c", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add("wide chars", function(R)
	local a = {}
	assert_equal(R.split("ä ö ü", a, "\x20"), 3)
	assert_equal(table.concat(a, "ß"), "äßößü")
end)

group:add("special null pattern splits every character", function(R)
	local a = {}
	assert_equal(R.split("abcäöü", a, ""), 6)
	assert_equal(table.concat(a, ","), "a,b,c,ä,ö,ü")
end)

group:add("simple one-chacter pattern", function(R)
	local a = {}
	assert_equal(R.split("..a.b.c.", a, "."), 6)
	assert_equal(table.concat(a, ";"), ";;a;b;c;")
end)

group:add("regular expression pattern pattern", function(R)
	local a = {}
	assert_equal(R.split(",a,b,,,c,", a, ",+"), 5)
	assert_equal(table.concat(a, ","), ",a,b,c,")
end)

group:run()
