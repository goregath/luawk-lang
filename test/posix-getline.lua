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

group:add('getline from path', function(R)
	local getline, state = R.getline(arg[0])
	R.RS = "\n"
	assert_type(getline, "function")
	assert_type(state, "table")
	assert_true(getline(state))
end)

group:add('getline from file handle', function(R)
	local file = io.open(arg[0])
	local record = file:read('l') file:seek('set')
	local getline, state = R.getline(file)
	R.RS = "\n"
	assert_type(getline, "function")
	assert_type(state, "table")
	assert_equal(getline(state), record)
end)

group:add('getline from function', function(R)
	local data = { "record", ":eof" }
	local function read()
		return table.remove(data, 1)
	end
	local getline, state = R.getline(read)
	R.RS = ":"
	assert_type(getline, "function")
	assert_type(state, "table")
	assert_equal(getline(state), "record")
	assert_equal(#data, 0)
end)

group:add('getline from coroutine', function(R)
	local data = { "record", ":eof" }
	local read = coroutine.wrap(function()
		for _, record in ipairs(data) do
			coroutine.yield(record)
		end
	end)
	local getline, state = R.getline(read)
	R.RS = ":"
	assert_type(getline, "function")
	assert_type(state, "table")
	assert_equal(getline(state), "record" )
end)

group:add('getline from stringio', function(R)
	local data = { "record", ":eof" }
	function data:read()
		return table.remove(self, 1)
	end
	local getline, state = R.getline(data)
	R.RS = ":"
	assert_type(getline, "function")
	assert_type(state, "table")
	assert_equal(getline(state), "record")
	assert_equal(#data, 0)
end)

group:add('cat file', function(R)
	local strbuf = {}
	for line, rt in R.getline(arg[0]) do
		table.insert(strbuf, line)
		table.insert(strbuf, rt)
	end
	local file = io.open(arg[0])
	assert_equal(table.concat(strbuf), file:read('*a'))
end)

group:add('set RS="" (special mode)', function(R)
	local records = {}
	local data = {
		"\n",
		"\n",
		"abc\n",
		"def\n",
		"\n",
		"\n",
		"ghi\n",
		"\n",
		"\n",
	}
	function data:read()
		return table.remove(self, 1)
	end
	R.RS = ""
	for record in R.getline(data) do
		table.insert(records, record)
	end
	assert_equal(#records, 2)
	assert_equal(records[1], "abc\ndef")
	assert_equal(records[2], "ghi")
end)

group:add('set RS="\\n\\n+"', function(R)
local records = {}
	local data = {
		"\n",
		"\n",
		"abc\n",
		"def\n",
		"\n",
		"\n",
		"ghi\n",
		"\n",
		"\n",
	}
	function data:read()
		return table.remove(self, 1)
	end
	R.RS = "\n\n+"
	for record in R.getline(data) do
		table.insert(records, record)
	end
	assert_equal(#records, 3)
	assert_equal(records[1], "")
	assert_equal(records[2], "abc\ndef")
	assert_equal(records[3], "ghi")
end)

group:run()