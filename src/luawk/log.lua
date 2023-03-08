local tblfmt
local modes = {
	{ name = "error", color = 31, },
	{ name = "warn",  color = 33, },
	{ name = "info",  color = 32, },
	{ name = "debug", color = 36, },
	{ name = "trace", color = 34, },
}

local log = { _version = "0.1.0" }
log.usecolor = true
log.level = "warn"

local levels = {}
for lvl, mode in ipairs(modes) do
	levels[mode.name] = lvl
end

for lvl, mode in ipairs(modes) do
	log[mode.name] = function(...)
		if lvl > levels[log.level] then
		  return
		end
		local fmt = ...
		local argc = select('#', ...)
		local argv = { select(2, ...) }
		local varg = setmetatable({}, {
			__index = function(_,k)
				local val = argv[k]
				local type = type(val)
				if type == "string" then
					return string.format("%q",tostring(val)):gsub("\\\n","\\n")
				elseif type == "number" then
					return tostring(val)
				elseif type == "table" and log.level == "trace" then
					if tblfmt == nil then
						local s, m = pcall(require, "inspect")
						tblfmt = s and m or false
					end
					return tblfmt and tblfmt(val) or val
				else
					return string.format("<%s>", tostring(val))
				end
			end,
			__len = function() return argc end
		})
		if log.usecolor then
			io.stderr:write("\27[",mode.color,";1m")
		end
		io.stderr:write(mode.name, ": ")
		if levels[log.level] >= levels["debug"] then
			local info = debug.getinfo(2, "Sl")
			local lineinfo = info.short_src .. ":" .. info.currentline
			io.stderr:write(lineinfo, ": ")
		end
		io.stderr:write("\27[0m\27[",mode.color,"m")
		io.stderr:write(string.format(fmt, table.unpack(varg)))
		if log.usecolor then
			io.stderr:write("\27[0m")
		end

	end
end

return log
