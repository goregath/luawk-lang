-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-03-10 10:01:08


package.path = "src/?.lua;" .. package.path

local assert_equal = require "test.utils".assert_equal
local assert_error = require "test.utils".assert_error

require 'luawk.log'.level = "trace"

do -- defaults
	local R = require("luawk.runtime"):new()
	assert(R ~= nil, "F is nil")
	assert_equal(R.NF, 0)
	assert_equal(#R, 0)
	assert_equal(R[0], "")
	assert_equal(R[1], nil)
	assert_equal(R.FS, " ")
	assert_equal(R.OFS, " ")
end

do -- setting record updates NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	assert_equal(R.NF, 3)
	assert_equal(#R, 3)
end

do -- table.insert on record updates NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	table.insert(R, 2, "x")
	assert_equal(R.NF, 4)
	assert_equal(#R, 4)
end

do -- table.remove on record retains NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	table.remove(R, 1)
	assert_equal(R.NF, 3)
	assert_equal(#R, 3)
end

do -- setting record splits to fields by FS
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], nil)
end

do -- ipairs of record
	local R = require("luawk.runtime"):new()
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
end

do -- touch NF forces record to recompute
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	assert_equal(R[0], " a b   c ")
	R.NF = R.NF
	assert_equal(R[0], "a,b,c")
end

do -- set OFS="," and NF=NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF
	assert_equal(R[0], "a,b,c")
end

do -- set NF=NF and OFS=","
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.NF = R.NF
	R.OFS = ","
	assert_equal(R[0], "a b c")
end

do -- replace last field
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R[R.NF] = "x"
	assert_equal(R[0], "a b x")
end

do -- table.insert appends field
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	table.insert(R, "x")
	assert_equal(R[0], "a b c x")
end

do -- table.remove clears field
	local R = require("luawk.runtime"):new()
	R.OFS = ","
	R[0] = " a b   c "
	table.remove(R, 2)
	assert_equal(R[0], "a,c,")
end

do -- decrement NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	assert_equal(#R, 2)
	assert_equal(R[0], "a,b")
end

do -- decrement NF updates fields
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.NF = R.NF - 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], nil)
end

do -- decrement NF updates record
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	assert_equal(R[0], "a,b")
end

do -- increment NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF + 1
	assert_equal(#R, 4)
	assert_equal(R[0], "a,b,c,")
end

do -- increment NF updates fields
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.NF = R.NF + 1
	assert_equal(R[1], "a")
	assert_equal(R[2], "b")
	assert_equal(R[3], "c")
	assert_equal(R[4], "")
	assert_equal(R[5], nil)
end

do -- increment NF updates record
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF + 1
	assert_equal(R[0], "a,b,c,")
end

do -- decrement/increment NF unset last field
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = R.NF - 1
	R.NF = R.NF + 1
	assert_equal(R[0], "a,b,")
end

do -- manually set NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = 5
	assert_equal(#R, 5)
	assert_equal(R[0], "a,b,c,,")
end

do -- set NF to zero
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	R.OFS = ","
	R.NF = 0
	assert_equal(#R, 0)
	assert_equal(R[0], "")
end

do -- set field outside NF updates NF
	local R = require("luawk.runtime"):new()
	R[0] = " a b   c "
	assert_equal(#R, 3)
	R[5] = "x"
	assert_equal(#R, 5)
	assert_equal(R.NF, 5)
end

-- do -- set NF to -1 causes error
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		R.NF = -1
-- 	end, "NF set to negative value$")
-- end

-- do -- access record at -1 causes error
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		return R[-1]
-- 	end, "access to negative field$")
-- end

-- do -- set record at -1 causes error
-- 	local R = require("luawk.runtime"):new()
-- 	assert_error(function()
-- 		R[-1] = nil
-- 	end, "access to negative field$")
-- end
