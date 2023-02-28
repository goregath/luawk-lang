-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-02-28 13:46:37

local assert_equal = require "test.utils".assert_equal
local split = require "awk.string".split
local patsplit = require "awk.string".patsplit

do -- split: defaults to FS="\x20"
	local a = {}
	assert_equal(split("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: special pattern of "\x20" automatically trims leading and trailingspaces
	local a = {}
	assert_equal(split("  a b c  ", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: special pattern of "\x20" automatically aggregate spaces
	local a = {}
	assert_equal(split("a  b  c", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- split: wide chars
	local a = {}
	assert_equal(split("ä ö ü", a, "\x20"), 3)
	assert_equal(table.concat(a, "ß"), "äßößü")
end

do -- split: special null pattern splits every character
	local a = {}
	assert_equal(split("abcäöü", a, ""), 6)
	assert_equal(table.concat(a, ","), "a,b,c,ä,ö,ü")
end

do -- split: simple one-chacter pattern
	local a = {}
	assert_equal(split(",,a,b,c,", a, ","), 6)
	assert_equal(table.concat(a, ";"), ";;a;b;c;")
end

do -- split: regular expression pattern pattern
	local a = {}
	assert_equal(split(",a,b,,,c,", a, ",+"), 5)
	assert_equal(table.concat(a, ","), ",a,b,c,")
end

do -- patsplit: fallback to env.FPATH
	local a = {}
	FPAT="%w+"
	assert_equal(patsplit("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end

do -- patsplit: extract words
	local a = {}
	assert_equal(patsplit("lorem ipsum, dolor sit amet", a, "%w+"), 5)
	assert_equal(table.concat(a, ","), "lorem,ipsum,dolor,sit,amet")
end

do -- patsplit: captures
	local a = {}
	assert_equal(patsplit("xa,b,xc", a, "x(%w)"), 2)
	assert_equal(table.concat(a, ";"), "a;c")
end