#!/usr/bin/env lua

local path = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
package.path = string.format("%s/../src/?.lua;%s/lua/lib/?.lua;%s", path, path, package.path)

local assert_equal = require "assert".assert_equal
local assert_true = require "assert".assert_true
local assert_type = require "assert".assert_type
local group = require "testgroup".new("luawk.runtime.posix getline()")

group:setup(function()
	return require "luawk.runtime.posix".new()
end)

group:add('open test file', function(R)
	local getline, state = R.getline(arg[0])
	assert_type(getline, "function")
	assert_type(state, "table")
end)

group:add('cat', function(R)
	local strbuf = {}
	for line, rt in R.getline(arg[0]) do
		table.insert(strbuf, line)
		table.insert(strbuf, rt)
	end
	local file = io.open(arg[0])
	assert_equal(table.concat(strbuf), file:read('*a'))
end)

group:add('set RS="" (special mode)', function(R)
	local tmpfile = io.tmpfile()
	local records = {}
	tmpfile:write(
		"\n",
		"\n",
		"abc\n",
		"def\n",
		"\n",
		"\n",
		"ghi\n",
		"\n",
		"\n"
	)
	tmpfile:seek("set")
	R.RS = ""
	for record in R.getline(tmpfile) do
		table.insert(records, record)
	end
	assert_equal(#records, 2)
	assert_equal(records[1], "abc\ndef")
	assert_equal(records[2], "ghi")
end)

group:add('set RS="\\n\\n+"', function(R)
	local tmpfile = io.tmpfile()
	local records = {}
	tmpfile:write(
		"\n",
		"\n",
		"abc\n",
		"def\n",
		"\n",
		"\n",
		"ghi\n",
		"\n",
		"\n"
	)
	tmpfile:seek("set")
	R.RS = "\n\n+"
	for record in R.getline(tmpfile) do
		table.insert(records, record)
	end
	assert_equal(#records, 3)
	assert_equal(records[1], "")
	assert_equal(records[2], "abc\ndef")
	assert_equal(records[3], "ghi")
end)

group:run()