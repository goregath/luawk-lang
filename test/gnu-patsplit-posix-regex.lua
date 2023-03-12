#!/usr/bin/env lua

local path = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
package.path = string.format("%s/../src/?.lua;%s/lua/lib/?.lua;%s", path, path, package.path)

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.runtime.gnu patsplit() with extended regex (lrexlib)")

local regex_find = require "luawk.regex".find

group:setup(function()
	local lrexlib = require "rex_posix"
	require "luawk.regex".find = lrexlib.find
	return require "luawk.runtime.gnu".new()
end)

group:teardown(function()
	require "luawk.regex".find = regex_find
end)

group:add("gawk csv example", function(self)
	-- See https://www.gnu.org/software/gawk/manual/html_node/Splitting-By-Content.html
	local a, s = {}, {}
	local input = ',Robbins,,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA,,'
	local fpat = '([^,]*)|("[^"]+")'
	local n = self.patsplit(input, a, fpat, s)
	-- print(require'inspect'(a))
	-- print(require'inspect'(s))
	assert_equal(n, 11)
	assert_equal(#a, 11)
	assert_equal(#s, 11) -- 11+1 (zeroth sep)
	assert_equal(s[00], "")
	assert_equal(a[01], "")
	assert_equal(s[01], ",")
	assert_equal(a[02], "Robbins")
	assert_equal(s[02], ",")
	assert_equal(a[03], "")
	assert_equal(s[03], ",")
	assert_equal(a[04], "Arnold")
	assert_equal(s[04], ",")
	assert_equal(a[05], '"1234 A Pretty Street, NE"')
	assert_equal(s[05], ",")
	assert_equal(a[06], "MyTown")
	assert_equal(s[06], ",")
	assert_equal(s[07], ",")
	assert_equal(a[07], "MyState")
	assert_equal(a[08], "12345-6789")
	assert_equal(s[08], ",")
	assert_equal(a[09], "USA")
	assert_equal(s[09], ",")
	assert_equal(a[10], "")
	assert_equal(s[10], ",")
	assert_equal(a[11], "")
	assert_equal(s[11], "")
end)

group:add("patterns without delimiter", function(self)
	local a = {}
	local input = 'deadbeef'
	local fpat = '[a-f][a-f]'
	local n = self.patsplit(input, a, fpat)
	assert_equal(n, 4)
	assert_equal(#a, 4)
	assert_equal(table.concat(a, ","), "de,ad,be,ef")
end)

group:run()