--- Logging module
--  @alias log
--  @module log

local getenv = require "posix.stdlib".getenv
local isatty = require "posix.unistd".isatty

local log = {}
local tblfmt
local modes = {
	{ name = "error", color = 31, },
	{ name = "warn",  color = 33, },
	{ name = "info",  color = 32, },
	{ name = "debug", color = 36, },
	{ name = "trace", color = 34, },
}

local levels = {}
for lvl, mode in ipairs(modes) do
	levels[mode.name] = lvl
end

--- Enable ANSI colors.
log._color = false

--- Default log level.
log._level = "warn"

--- Test if `io.stdout` is connected to a TTY with color support.
--
--  This function is equivalent to this common idiom in C:
--
--    #include <stdlib.h>
--    #include <unistd.h>
--    #include <string.h>
--
--    int main() {
--      if (isatty(STDOUT_FILENO)) {
--        char *term = getenv("TERM");
--        if (term && strcmp(term, "dumb") != 0) {
--          return 0;
--        }
--      }
--      return 1;
--    }
--
--  @return success if color is supported, fail otherwise
--
--  @see isatty(3)
--  @see getenv(3)
--  @see strcmp(3)
--  @see posix.unistd
--  @see posix.stdlib
function log.colorsupport()
    local term = getenv("TERM")
    return isatty(1) and term and term ~= "dumb"
end

--- Set log level.
function log.level(lvl)
	if not levels[lvl] then
		error(string.format("unknown log level %q", lvl), -1)
	end
	log._level = lvl
end

--- Manually enable/disable colors.
function log.color(flag)
	log._color = flag
end

--- @function log.error

--- @function log.warn

--- @function log.info

--- @function log.debug

--- @function log.trace

for lvl, mode in ipairs(modes) do
	log[mode.name] = function(...)
		if lvl > levels[log._level] then
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
				elseif type == "table" and log._level == "trace" then
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
		if log._color then
			io.stderr:write("\27[",mode.color,";1m")
		end
		io.stderr:write(mode.name, ": ")
		if levels[log._level] >= levels["debug"] then
			local info = debug.getinfo(2, "Sl")
			local lineinfo = info.short_src .. ":" .. info.currentline
			io.stderr:write(lineinfo, ": ")
		end
		if log._color then
			io.stderr:write("\27[0m\27[",mode.color,"m")
		end
		io.stderr:write(string.format(fmt, table.unpack(varg)))
		if log._color then
			io.stderr:write("\27[0m")
		end

	end
end

log._color = log.colorsupport() and true or false

return log
