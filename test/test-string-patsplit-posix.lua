-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-02-28 19:19:05

require "inspect"
local assert_equal = require "test.utils".assert_equal
local patsplit = require "awk.string".patsplit

local lib = require "rex_posix"
string.find = lib.find

do -- patsplit: gawk csv example
	local a = {}
	local input = ',Robbins,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA,,'
	local fpat = '([^,]*)|("[^"]+")'
	assert_equal(patsplit(input, a, fpat), 10)
	print(require"inspect"(a))
	assert_equal(table.concat(a, ";"), "")
end