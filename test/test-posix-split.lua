package.path = "src/?.lua;test/lua/lib/?.lua;" .. package.path

local assert_equal = require "assert".assert_equal
local group = require "testgroup".new("luawk.runtime.posix split()")

group:setup(function()
	return require "luawk.runtime.posix".new()
end)

group:add('split: defaults to FS="\\x20"', function(R)
	local a = {}
	assert_equal(R.FS, "\32")
	assert_equal(R.split("a b c", a), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add('split: special pattern of "\\x20" automatically trims leading and trailingspaces', function(R)
	local a = {}
	assert_equal(R.split("  a b c  ", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add('split: special pattern of "\\x20" automatically aggregate spaces', function(R)
	local a = {}
	assert_equal(R.split("a  b  c", a, "\x20"), 3)
	assert_equal(table.concat(a, ","), "a,b,c")
end)

group:add("split: wide chars", function(R)
	local a = {}
	assert_equal(R.split("ä ö ü", a, "\x20"), 3)
	assert_equal(table.concat(a, "ß"), "äßößü")
end)

group:add("split: special null pattern splits every character", function(R)
	local a = {}
	assert_equal(R.split("abcäöü", a, ""), 6)
	assert_equal(table.concat(a, ","), "a,b,c,ä,ö,ü")
end)

group:add("split: simple one-chacter pattern", function(R)
	local a = {}
	assert_equal(R.split(",,a,b,c,", a, ","), 6)
	assert_equal(table.concat(a, ";"), ";;a;b;c;")
end)

group:add("split: regular expression pattern pattern", function(R)
	local a = {}
	assert_equal(R.split(",a,b,,,c,", a, ",+"), 5)
	assert_equal(table.concat(a, ","), ",a,b,c,")
end)

return group