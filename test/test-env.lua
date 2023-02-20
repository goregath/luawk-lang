-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   goregath
-- @Last Modified time: 2023-02-20 23:52:11

local function assert_equal(test, expected)
	if test ~= expected then
		error(string.format("assert_equal: expected %q, was %q", expected, test), 2)
	end
end

local function assert_re(test, pattern)
	if not string.match(test, pattern) then
		error(string.format("assert_re:  %q did not match %q", test, pattern), 2)
	end
end

local function assert_error(f, pattern)
	local s, m = pcall(f)
	if s ~= false then
		error("assert_error: succeeded")
	end
	if pattern ~= nil then
		assert_re(m, pattern)
	end
end

do -- defaults
	local E, R = require("awk.env"):new()
	assert(R ~= nil, "F is nil")
	assert_equal(E.NF, 0)
	assert_equal(#R, 0)
	assert_equal(R[0], "")
	assert_equal(R[1], nil)
	assert_equal(E.FS, " ")
	assert_equal(E.OFS, " ")
end

do -- setting record updates NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	assert_equal(E.NF, 3)
	assert_equal(#R, 3)
end

do -- table.insert on record updates NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	table.insert(R, 2, "x")
	assert_equal(E.NF, 4)
	assert_equal(#R, 4)
end

do -- table.remove on record retains NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	table.remove(R, 1)
	assert_equal(E.NF, 3)
	assert_equal(#R, 3)
end

do -- setting record splits to fields by FS
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], nil)
end

do -- ipairs of record
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.NF = 5
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
end

do -- touch NF forces record to recompute
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	assert_equal(R[0], " a b   c ")
	E.NF = E.NF
	assert_equal(R[0], "a,b,c")
end

do -- set OFS="," and NF=NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF
	assert_equal(R[0], "a,b,c")
end

do -- set NF=NF and OFS=","
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.NF = E.NF
	E.OFS = ","
	assert_equal(R[0], "a b c")
end

do -- replace last field
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	R[E.NF] = "x"
	assert_equal(R[0], "a b x")
end

do -- table.insert appends field
	local _, R = require("awk.env"):new()
	R[0] = " a b   c "
	table.insert(R, "x")
	assert_equal(R[0], "a b c x")
end

do -- table.remove clears field
	local E, R = require("awk.env"):new()
	E.OFS = ","
	R[0] = " a b   c "
	table.remove(R, 2)
	assert_equal(R[0], "a,c,")
end

do -- decrement NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF - 1
	assert_equal(#R, 2)
	assert_equal(R[0], "a,b")
end

do -- decrement NF updates fields
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.NF = E.NF - 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], nil)
end

do -- decrement NF updates record
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF - 1
	assert_equal(R[0], "a,b")
end

do -- increment NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF + 1
	assert_equal(#R, 4)
	assert_equal(R[0], "a,b,c,")
end

do -- increment NF updates fields
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.NF = E.NF + 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], "")
	assert_equal(R[5], nil)
end

do -- increment NF updates record
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF + 1
	assert_equal(R[0], "a,b,c,")
end

do -- decrement/increment NF unset last field
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = E.NF - 1
	E.NF = E.NF + 1
	assert_equal(R[0], "a,b,")
end

do -- manually set NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = 5
	assert_equal(#R, 5)
	assert_equal(R[0], "a,b,c,,")
end

do -- set NF to zero
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	E.OFS = ","
	E.NF = 0
	assert_equal(#R, 0)
	assert_equal(R[0], "")
end

do -- set field outside NF updates NF
	local E, R = require("awk.env"):new()
	R[0] = " a b   c "
	assert_equal(#R, 3)
	R[5] = "x"
	assert_equal(#R, 5)
	assert_equal(E.NF, 5)
end

do -- set NF to -1 causes error
	local E, R = require("awk.env"):new()
	assert_error(function()
		E.NF = -1
	end, "NF set to negative value$")
end

do -- access record at -1 causes error
	local E, R = require("awk.env"):new()
	assert_error(function()
		return R[-1]
	end, "access to negative field$")
end

do -- set record at -1 causes error
	local E, R = require("awk.env"):new()
	assert_error(function()
		R[-1] = nil
	end, "access to negative field$")
end
