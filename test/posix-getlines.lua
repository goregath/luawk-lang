#!/bin/sh -e

if true --[[; then
	cd "${0%/*}/.."
	exec /usr/bin/env lua -lluacov "test/${0##*/}" "$@"
fi; --]] then
	package.path = "lib/?.lua;lib/?/init.lua;test/lua/lib/?.lua;" .. package.path
end

local assert_equal = require "assert".assert_equal
local assert_true = require "assert".assert_true
local assert_type = require "assert".assert_type
local group = require "testgroup".new("luawk.environment.posix getlines()")
local iomock = {}

function iomock.open(tbl)
	return setmetatable(tbl, { __index = iomock })
end

function iomock:read()
	return table.remove(self, 1)
end

group:setup(function()
	return require "luawk.environment.posix".new()
end)

group:add('getlines from path', function(R)
	local getlines, state = R.getlines(arg[0])
	R.RS = "\n"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_true(getlines(state))
end)

group:add('getlines from file handle', function(R)
	local file = io.open(arg[0])
	local record = file:read('l') file:seek('set')
	local getlines, state = R.getlines(file)
	R.RS = "\n"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), record)
end)

group:add('getlines from process handle', function(R)
	local file = io.popen("echo 'record:eof'")
	local getlines, state = R.getlines(file)
	R.RS = ":"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), "record")
end)

group:add('getlines from function', function(R)
	local data = { "rec", "ord:eof" }
	local function read()
		return table.remove(data, 1)
	end
	local getlines, state = R.getlines(read)
	R.RS = ":"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), "record")
	assert_equal(#data, 0)
end)

group:add('getlines from function (coroutine.wrap)', function(R)
	local data = { "rec", "ord:eof" }
	local read = coroutine.wrap(function()
		for _, record in ipairs(data) do
			coroutine.yield(record)
		end
	end)
	local getlines, state = R.getlines(read)
	R.RS = ":"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), "record" )
end)

group:add('getlines from coroutine', function(R)
	local data = { "rec", "ord:eof" }
	local read = coroutine.create(function()
		for _, record in ipairs(data) do
			coroutine.yield(record)
		end
	end)
	local getlines, state = R.getlines(read)
	R.RS = ":"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), "record" )
end)


group:add('getlines from mocked file object', function(R)
	local data = iomock.open { "rec", "ord:eof" }
	local getlines, state = R.getlines(data)
	R.RS = ":"
	assert_type(getlines, "function")
	assert_type(state, "table")
	assert_equal(getlines(state), "record")
	assert_equal(#data, 0)
end)

group:add('cat file', function(R)
	local strbuf = {}
	for line, rt in R.getlines(arg[0]) do
		table.insert(strbuf, line)
		table.insert(strbuf, rt)
	end
	local file = io.open(arg[0])
	assert_equal(table.concat(strbuf), file:read('*a'))
end)

group:add('set RS="" (special mode)', function(R)
	local records = {}
	local data = iomock.open {
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
	R.RS = ""
	for record in R.getlines(data) do
		table.insert(records, record)
	end
	assert_equal(#records, 2)
	assert_equal(records[1], "abc\ndef")
	assert_equal(records[2], "ghi")
end)

group:add('set RS="\\n\\n+"', function(R)
local records = {}
	local data = iomock.open {
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
	R.RS = "\n\n+"
	for record in R.getlines(data) do
		table.insert(records, record)
	end
	assert_equal(#records, 3)
	assert_equal(records[1], "")
	assert_equal(records[2], "abc\ndef")
	assert_equal(records[3], "ghi")
end)

group:add('set RS="" (FS always matches "\\n")', function(R)
	local data = iomock.open {
		"a,b,c\n",
		"d, e, f\n",
		"\n",
		"x\n",
		"y\n",
		"z\n",
	}
	local getlines, state = R.getlines(data)
	R.RS = ""
	R.FS = "[ ,]+"
	R[0] = getlines(state)
	assert_equal(#R, 6)
	assert_equal(table.concat(R), "abcdef")
	R[0] = getlines(state)
	assert_equal(#R, 3)
	assert_equal(table.concat(R), "xyz")
	assert_equal(getlines(state), nil)
end)

group:run()