--- Regex type.
-- @alias M
-- @module type.regex

local posix = require 'luawk.environment.posix'

local M = {}

local remt = {
	__bxor = function(l,r)
		return posix.class.match({},l,r)
	end,
	-- __add = function(l,r)
	-- 	return posix.class.match({},l,r)
	-- end,
	__tostring = function(t)
		return t.re
	end
}

--- New object of regex type.
function M.new(s)
	return setmetatable({ re = s }, remt)
end

return M