#!/usr/bin/env lua

local path = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
package.path = string.format("%s/../src/?.lua;%s/lua/lib/?.lua;%s", path, path, package.path)

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("record and field splitting")

group:setup(function()
	return require "luawk.environment.posix".new()
end)

group:add("defaults", function(R)
	assert(R ~= nil, "F is nil")
	assert_equal(R.NF, 0)
	assert_equal(#R, 0)
	assert_equal(R[0], "")
	assert_equal(R[1], nil)
	assert_equal(R.FS, " ")
	assert_equal(R.OFS, " ")
end)

group:add("setting record updates NF", function(R)
	R[0] = " a b   c "
	assert_equal(R.NF, 3)
	assert_equal(#R, 3)
end)

group:add("table.insert on record updates NF", function(R)
	R[0] = " a b   c "
	table.insert(R, 2, "x")
	assert_equal(R.NF, 4)
	assert_equal(#R, 4)
end)

group:add("table.remove on record retains NF", function(R)
	R[0] = " a b   c "
	table.remove(R, 1)
	assert_equal(R.NF, 3)
	assert_equal(#R, 3)
end)

group:add("setting record splits to fields by FS", function(R)
	R[0] = " a b   c "
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], nil)
end)

group:add("ipairs of record", function(R)
	R[0] = " a b   c "
	R.NF = 5
	local f = {}
	for _,v in ipairs(R) do
		table.insert(f, v or false)
	end
	assert_equal(#f, 5)
	assert_equal(f[1], "a")
	assert_equal(f[2], "b")
	assert_equal(f[3], "c")
	assert_equal(f[4], "")
	assert_equal(f[5], "")
end)

group:add("touch NF forces record to recompute", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	assert_equal(R[0], " a b   c ")
	R.NF = R.NF
	assert_equal(R[0], "a,b,c")
end)

group:add('set OFS="," and NF=NF', function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF
	assert_equal(R[0], "a,b,c")
end)

group:add('set NF=NF and OFS=","', function(R)
	R[0] = " a b   c "
	R.NF = R.NF
	R.OFS = ","
	assert_equal(R[0], "a b c")
end)

group:add('set field and OFS=","', function(R)
	R[0] = " a b   c "
	R[2] = "x"
	R.OFS = ","
	assert_equal(R[0], "a x c")
end)

group:add("replace last field", function(R)
	R[0] = " a b   c "
	R[R.NF] = "x"
	assert_equal(R[0], "a b x")
end)

group:add("table.insert appends field", function(R)
	R[0] = " a b   c "
	table.insert(R, "x")
	assert_equal(R[0], "a b c x")
end)

group:add("table.remove clears field", function(R)
	R.OFS = ","
	R[0] = " a b   c "
	table.remove(R, 2)
	assert_equal(R[0], "a,c,")
end)

group:add("decrement NF", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	assert_equal(#R, 2)
	assert_equal(R[0], "a,b")
end)

group:add("decrement NF updates fields", function(R)
	R[0] = " a b   c "
	R.NF = R.NF - 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], nil)
end)

group:add("decrement NF updates record", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	assert_equal(R[0], "a,b")
end)

group:add("increment NF", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF + 1
	assert_equal(#R, 4)
	assert_equal(R[0], "a,b,c,")
end)

group:add("increment NF updates fields", function(R)
	R[0] = " a b   c "
	R.NF = R.NF + 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], "")
	assert_equal(R[5], nil)
end)

group:add("increment NF updates record", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF + 1
	assert_equal(R[0], "a,b,c,")
end)

group:add("decrement/increment NF unset last field", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	R.NF = R.NF + 1
	assert_equal(R[0], "a,b,")
end)

group:add("manually set NF", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = 5
	assert_equal(#R, 5)
	assert_equal(R[0], "a,b,c,,")
end)

group:add("set NF to zero", function(R)
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = 0
	assert_equal(#R, 0)
	assert_equal(R[0], "")
end)

group:add("set field outside NF updates NF", function(R)
	R[0] = " a b   c "
	assert_equal(#R, 3)
	R[5] = "x"
	assert_equal(#R, 5)
	assert_equal(R.NF, 5)
end)

-- local assert_error = require "test.utils".assert_error

-- group:add("set NF to -1 causes error", function(R)
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		R.NF = -1
-- 	end, "NF set to negative value$")
-- end

-- group:add("access record at -1 causes error", function(R)
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		return R[-1]
-- 	end, "access to negative field$")
-- end

-- group:add("set record at -1 causes error", function(R)
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		R[-1] = nil
-- 	end, "access to negative field$")
-- end

group:run()