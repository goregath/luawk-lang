-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   goregath
-- @Last Modified time: 2023-02-05 19:26:38

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
	local A = require("awk.env"):new()
	assert(A.F ~= nil, "F is nil")
	assert_equal(A.NF, 0)
	assert_equal(#A.F, 0)
	assert_equal(A.F[0], "")
	assert_equal(A.F[1], nil)
	assert_equal(A.FS, " ")
	assert_equal(A.OFS, " ")
end

do -- setting record updates NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	assert_equal(#A.F, 3)
	assert_equal(A.NF, 3)
end

do -- setting record splits to fields by FS
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	assert_equal(A.F[1], "a")
	assert_equal(A.F[2], "b")
	assert_equal(A.F[3], "c")
	assert_equal(A.F[4], nil)
end

do -- ipairs of record
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.NF = 5
	local f = {}
	for _,v in ipairs(A.F) do
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
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF
	assert_equal(A.F[0], "a,b,c")
end

do -- set OFS="," and NF=NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF
	assert_equal(A.F[0], "a,b,c")
end

do -- set NF=NF and OFS=","
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.NF = A.NF
	A.OFS = ","
	assert_equal(A.F[0], "a b c")
end

do -- replace last field
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.F[A.NF] = "x"
	assert_equal(A.F[0], "a b x")
end

do -- decrement NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF - 1
	assert_equal(#A.F, 2)
	assert_equal(A.F[0], "a,b")
end

do -- decrement NF updates fields
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.NF = A.NF - 1
	assert_equal(A.F[1], "a")
	assert_equal(A.F[2], "b")
	assert_equal(A.F[3], nil)
end

do -- decrement NF updates record
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF - 1
	assert_equal(A.F[0], "a,b")
end

do -- increment NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF + 1
	assert_equal(#A.F, 4)
	assert_equal(A.F[0], "a,b,c,")
end

do -- increment NF updates fields
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.NF = A.NF + 1
	assert_equal(A.F[1], "a")
	assert_equal(A.F[2], "b")
	assert_equal(A.F[3], "c")
	assert_equal(A.F[4], "")
	assert_equal(A.F[5], nil)
end

do -- increment NF updates record
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF + 1
	assert_equal(A.F[0], "a,b,c,")
end

do -- decrement/increment NF unset last field
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = A.NF - 1
	A.NF = A.NF + 1
	assert_equal(A.F[0], "a,b,")
end

do -- manually set NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = 5
	assert_equal(#A.F, 5)
	assert_equal(A.F[0], "a,b,c,,")
end

do -- set NF to zero
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	A.OFS = ","
	A.NF = 0
	assert_equal(#A.F, 0)
	assert_equal(A.F[0], "")
end

do -- set field outside NF updates NF
	local A = require("awk.env"):new()
	A.F[0] = " a b   c "
	assert_equal(#A.F, 3)
	A.F[5] = "x"
	assert_equal(#A.F, 5)
	assert_equal(A.NF, 5)
end

do -- set NF to -1 causes error
	local A = require("awk.env"):new()
	assert_error(function()
		A.NF = -1
	end, "NF set to negative value$")
end

do -- access record at -1 causes error
	local A = require("awk.env"):new()
	assert_error(function()
		return A.F[-1]
	end, "access to negative field$")
end

do -- set record at -1 causes error
	local A = require("awk.env"):new()
	assert_error(function()
		A.F[-1] = nil
	end, "access to negative field$")
end

-- luacheck: globals FS
-- do
-- 	local _ENV = awkenv.new(_ENV or _G)
-- 	_ENV[0] = " a b   c "
-- 	assert(NF == 3)
-- 	assert(#_ENV == 3)
-- 	assert(_ENV[1] == "a")
-- 	assert(_ENV[1.5] == "a")
-- 	assert(_ENV[2] == "b")
-- 	assert(_ENV[3] == "c")
-- 	assert(_ENV[4] == nil)
-- 	_ENV[3] = nil
-- 	assert(NF == 3)
-- 	assert(#_ENV == 3)
-- 	-- NF = 2
-- 	-- assert(_ENV[1] == "a")
-- 	-- assert(_ENV[2] == "b")
-- 	-- assert(_ENV[3] == nil)
-- end