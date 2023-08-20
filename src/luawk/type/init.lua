--- Mimic the AWK type system.

-- __add: the addition (+) operation. If any operand for an addition is not a
--   number, Lua will try to call a metamethod. It starts by checking the
--   first operand (even if it is a number); if that operand does not define
--   a metamethod for __add, then Lua will check the second operand. If Lua
--   can find a metamethod, it calls the metamethod with the two operands as
--   arguments, and the result of the call (adjusted to one value) is the
--   result of the operation. Otherwise, if no metamethod is found, Lua
--   raises an error.
-- __sub: the subtraction (-) operation. Behavior similar to the addition
--   operation.
-- __mul: the multiplication (*) operation. Behavior similar to the addition
--   operation.
-- __div: the division (/) operation. Behavior similar to the addition
--   operation.
-- __mod: the modulo (%) operation. Behavior similar to the addition
--   operation.
-- __pow: the exponentiation (^) operation. Behavior similar to the addition
--   operation.
-- __unm: the negation (unary -) operation. Behavior similar to the addition
--   operation.
-- __idiv: the floor division (//) operation. Behavior similar to the addition
--   operation.
-- __band: the bitwise AND (&) operation. Behavior similar to the addition
--   operation, except that Lua will try a metamethod if any operand is
--   neither an integer nor a float coercible to an integer (see §3.4.3).
-- __bor: the bitwise OR (|) operation. Behavior similar to the bitwise AND
--   operation.
-- __bxor: the bitwise exclusive OR (binary ~) operation. Behavior similar to
--   the bitwise AND operation.
-- __bnot: the bitwise NOT (unary ~) operation. Behavior similar to the
--   bitwise AND operation.
-- __shl: the bitwise left shift (<<) operation. Behavior similar to the
--   bitwise AND operation.
-- __shr: the bitwise right shift (>>) operation. Behavior similar to the
--   bitwise AND operation.
-- __concat: the concatenation (..) operation. Behavior similar to the
--   addition operation, except that Lua will try a metamethod if any operand
--   is neither a string nor a number (which is always coercible to a
--   string).
-- __len: the length (#) operation. If the object is not a string, Lua will
--   try its metamethod. If there is a metamethod, Lua calls it with the
--   object as argument, and the result of the call (always adjusted to one
--   value) is the result of the operation. If there is no metamethod but the
--   object is a table, then Lua uses the table length operation
--   (see §3.4.7). Otherwise, Lua raises an error.
-- __eq: the equal (==) operation. Behavior similar to the addition operation,
--   except that Lua will try a metamethod only when the values being
--   compared are either both tables or both full userdata and they are not
--   primitively equal. The result of the call is always converted to a
--   boolean.
-- __lt: the less than (<) operation. Behavior similar to the addition
--   operation, except that Lua will try a metamethod only when the values
--   being compared are neither both numbers nor both strings. Moreover, the
--   result of the call is always converted to a boolean.
-- __le: the less equal (<=) operation. Behavior similar to the less than
--   operation.
-- __index: The indexing access operation table[key]. This event happens when
--   table is not a table or when key is not present in table. The metavalue
--   is looked up in the metatable of table.

-- local function call(...)
-- 	local v, s = ...
-- 	print(...)
-- 	print(debug.traceback())
-- 	if v then pcall(load(tostring(s))) end
-- end

local function atoi(e)
	return e == true and 1 or tonumber(e) or 0
end

local function clone(t)
	local new = {}
	for k,v in pairs(t) do
		new[k] = v
	end
	return new
end

local M = {}

local oldstrmt = debug.getmetatable("")
local oldintmt = debug.getmetatable(0)
local oldbolmt = debug.getmetatable(true)
local oldnilmt = debug.getmetatable(nil)

local intmt = clone(oldintmt or {})
local strmt = clone(oldstrmt or {})

function strmt.__add(l,r) return  atoi(l) +  atoi(r) end
function strmt.__sub(l,r) return  atoi(l) -  atoi(r) end
function strmt.__mul(l,r) return  atoi(l) *  atoi(r) end
function strmt.__div(l,r) return  atoi(l) /  atoi(r) end
function strmt.__mod(l,r) return  atoi(l) %  atoi(r) end
function strmt.__pow(l,r) return  atoi(l) ^  atoi(r) end
function strmt.__lt (l,r) return  atoi(l) <  atoi(r) end
function strmt.__le (l,r) return  atoi(l) <= atoi(r) end
function strmt.__unm(l)   return -atoi(l) end

function intmt.__add(l, r) return  (atoi(l) or l and 1 or 0) +  (atoi(r) or r and 1 or 0)  end
function intmt.__sub(l, r) return  (atoi(l) or l and 1 or 0) -  (atoi(r) or r and 1 or 0)  end
function intmt.__mul(l, r) return  (atoi(l) or l and 1 or 0) *  (atoi(r) or r and 1 or 0)  end
function intmt.__div(l, r) return  (atoi(l) or l and 1 or 0) /  (atoi(r) or r and 1 or 0)  end
function intmt.__mod(l, r) return  (atoi(l) or l and 1 or 0) %  (atoi(r) or r and 1 or 0)  end
function intmt.__pow(l, r) return  (atoi(l) or l and 1 or 0) ^  (atoi(r) or r and 1 or 0)  end
function intmt.__lt (l, r) return  (atoi(l) or l and 1 or 0) <  (atoi(r) or r and 1 or 0)  end
function intmt.__le (l, r) return  (atoi(l) or l and 1 or 0) <= (atoi(r) or r and 1 or 0)  end
function intmt.__unm(l)    return -(atoi(l) or l and 1 or 0)  end
function intmt.__tostring(l) return (tonumber(l) or "")  end

function M.enable()
	debug.setmetatable("",   strmt)
	debug.setmetatable(0,    intmt)
	debug.setmetatable(true, intmt)
	debug.setmetatable(nil,  intmt)
end

function M.disable()
	debug.setmetatable("",   oldstrmt)
	debug.setmetatable(0,    oldintmt)
	debug.setmetatable(true, oldbolmt)
	debug.setmetatable(nil,  oldnilmt)
end

return M