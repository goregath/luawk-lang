-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   goregath
-- @Last Modified time: 2023-03-06 12:45:39

package.path = "src/?.lua;" .. package.path

local relib = require "rex_posix"
local assert_equal = require "test.utils".assert_equal

require "luawk.regex".find = relib.find
local lib = require "luawk.runtime.gnu".new()

do -- patsplit: gawk csv example
	-- See https://www.gnu.org/software/gawk/manual/html_node/Splitting-By-Content.html
	local a, s = {}, {}
	local input = ',Robbins,,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA,,'
	local fpat = '([^,]*)|("[^"]+")'
	local n = lib.patsplit(input, a, fpat, s)
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
end

do -- patsplit: patterns without delimiter
	local a = {}
	local input = 'deadbeef'
	local fpat = '[a-f][a-f]'
	local n = lib.patsplit(input, a, fpat)
	assert_equal(n, 4)
	assert_equal(#a, 4)
	assert_equal(table.concat(a, ","), "de,ad,be,ef")
end