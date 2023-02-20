-- @Author: goregath
-- @Date:   2023-01-21 01:18:34
-- @Last Modified by:   goregath
-- @Last Modified time: 2023-02-04 15:01:51


-- require "compat53"
-- local awkenv = require "awk.env"
local awkstring = require "awk.string"

local a = {}
assert(awkstring.split("a b c", a) == 3)
assert(table.concat(a, ",") == "a,b,c")

assert(awkstring.split("ä ö ü", a) == 3)
assert(table.concat(a, "ß") == "äßößü")

assert(awkstring.split("  a b  c  ", a) == 3)
assert(table.concat(a, ",") == "a,b,c")

assert(awkstring.split("a  b  c", a) == 3)
assert(table.concat(a, ",") == "a,b,c")

assert(awkstring.split("abc", a, "") == 3)
assert(table.concat(a, ",") == "a,b,c")

assert(awkstring.split(",a,b,c,", a, ",") == 5)
assert(table.concat(a, ",") == ",a,b,c,")

assert(awkstring.split(",a,b,,,c,", a, ",+") == 5)
assert(table.concat(a, ",") == ",a,b,c,")

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