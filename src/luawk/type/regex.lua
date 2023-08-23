--- Regex type.
-- @alias M
-- @module type.regex

--- New object of regex type.
return function(p,e)
	local P = { P = p, _ENV = e }
	return setmetatable(P, {
		__bxor = function(l,r)
			return e.match(l,r)
		end,
		__add = function(l,r)
			if l == P then
				return e.match(e[0],l.P) + r
			else
				return l + e.match(e[0],r.P)
			end
		end,
		__tostring = function(t)
			return t.P
		end
	})
end