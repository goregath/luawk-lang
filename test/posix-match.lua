#!/usr/bin/env lua

local path = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
package.path = string.format("%s/../src/?.lua;%s/lua/lib/?.lua;%s", path, path, package.path)

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.runtime.posix split()")

group:setup(function()
	return require "luawk.runtime.posix".new()
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