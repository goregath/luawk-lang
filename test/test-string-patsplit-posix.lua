-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-03-01 14:25:28

require "inspect"
local assert_equal = require "test.utils".assert_equal
local patsplit = require "awk.string".patsplit

local lib = require "rex_posix"
string.find = lib.find

do -- patsplit: gawk csv example
	-- See https://www.gnu.org/software/gawk/manual/html_node/Splitting-By-Content.html
	local a, s = {}, {}
	local input = ',Robbins,,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA,,'
	local fpat = '([^,]*)|("[^"]+")'
	local n = patsplit(input, a, fpat, s)
	print(require'inspect'(a))
	print(require'inspect'(s))
	assert_equal(n, 11)
	assert_equal(#a, 11)
	assert_equal(#s, 11)
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
end

do -- patsplit: patterns without delimiter
	local a = {}
	local input = 'deadbeef'
	local fpat = '[a-f][a-f]'
	local n = patsplit(input, a, fpat)
	assert_equal(n, 4)
	assert_equal(#a, 4)
	assert_equal(table.concat(a, ","), "de,ad,be,ef")
end