-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   goregath
-- @Last Modified time: 2023-03-02 00:08:52

local assert_equal = require "test.utils".assert_equal
local env = { FS = '\32', FPAT = '%w+' }
local lib = require "awk.string":new(env)

do -- split: defaults to FS="\x20"
	local a = {}
	assert_equal(lib:split("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: special pattern of "\x20" automatically trims leading and trailingspaces
	local a = {}
	assert_equal(lib:split("  a b c  ", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: special pattern of "\x20" automatically aggregate spaces
	local a = {}
	assert_equal(lib:split("a  b  c", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: wide chars
	local a = {}
	assert_equal(lib:split("ä ö ü", a, "\x20"), 3)
	assert_equal(table.concat(a, "ß"), "äßößü")
end

do -- split: special null pattern splits every character
	local a = {}
	assert_equal(lib:split("abcäöü", a, ""), 6)
	assert_equal(table.concat(a, ","), "a,b,c,ä,ö,ü")
end

do -- split: simple one-chacter pattern
	local a = {}
	assert_equal(lib:split(",,a,b,c,", a, ","), 6)
	assert_equal(table.concat(a, ";"), ";;a;b;c;")
end

do -- split: regular expression pattern pattern
	local a = {}
	assert_equal(lib:split(",a,b,,,c,", a, ",+"), 5)
	assert_equal(table.concat(a, ","), ",a,b,c,")
end

do -- patsplit: fallback to env.FPATH
	local a = {}
	assert_equal(lib:patsplit("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- patsplit: extract words
	local a = {}
	assert_equal(lib:patsplit("lorem-ipsum, dolor sit amet", a, "[%w-]+"), 4)
	assert_equal(table.concat(a, ","), "lorem-ipsum,dolor,sit,amet")
end

do -- patsplit: dead beef
	local a, s = {}, {}
	local n = lib:patsplit("0xDEAD, 0xBEEF", a, "%x%x", s)
	assert_equal(n, 4)
	assert_equal(#a, 4)
	assert_equal(#s, 4)
	assert_equal(s[0],  "0x")
	assert_equal(a[1],  "DE")
	assert_equal(s[1],  "")
	assert_equal(a[2],  "AD")
	assert_equal(s[2],  ", 0x")
	assert_equal(a[3],  "BE")
	assert_equal(s[3],  "")
	assert_equal(a[4],  "EF")
	assert_equal(s[4],  "")
end

do -- patsplit: split path
	local a = {}
	assert_equal(lib:patsplit("/etc//passwd/", a, "[^/]+"), 2)
	assert_equal(table.concat(a, ","), "etc,passwd")
end

do -- patsplit: trailing case
	local a, s = {}, {}
	local n = lib:patsplit("bbbaaacccdddaaaaaqqqqa", a, "aa+", s)
	assert_equal(n, 2)
	assert_equal(#a, 2)
	assert_equal(#s, 2)
	assert_equal(s[0],  "bbb")
	assert_equal(a[1],  "aaa")
	assert_equal(s[1],  "cccddd")
	assert_equal(a[2],  "aaaaa")
	assert_equal(s[2],  "qqqqa")
end

-- do -- patsplit: captures
-- 	local a = {}
-- 	assert_equal(lib:patsplit("$a,b,c\n$def;g", a, "$?(%w+)"), 5)
-- 	assert_equal(table.concat(a, ","), "a,b,c,def,g")
-- end

-- do -- patsplit: multiple captures
-- 	local a = {}
-- 	assert_equal(lib:patsplit("a=1 b c=a x", a, "((%w+)=(%w+))"), 2)
-- 	assert_equal(table.concat(a, ","), "a=1,a,1,c=a,c,a")
-- end