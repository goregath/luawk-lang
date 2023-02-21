#!/usr/bin/env lua

-- @Author: Oliver Zimmer
-- @Date:   2023-02-20 11:22:41
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-02-21 13:26:36

local awkenv = require "awk.env"
local awkstr = require "awk.string"

local fileinfo = {}
local actions = {}
local _env, _record = awkenv:new()

-----------------------------------------------------------
-- UTILITIES
-----------------------------------------------------------

--- Compatibility layer setfenv() for Lua 5.2+.
--  Taken from Penlight Lua Libraries (lunarmodules/Penlight).
local setfenv = _G.setfenv or function(f, t)
	local name
	local up = 0
	repeat
		up = up + 1
		name = debug.getupvalue(f, up)
	until name == '_ENV' or name == nil
	if name then
		debug.upvaluejoin(f, up, function() return name end, 1) -- use unique upvalue
		debug.setupvalue(f, up, t)
	end
	if f ~= 0 then return f end
end

-----------------------------------------------------------
-- AWK FUNCTIONS AND KEYWORDS
-----------------------------------------------------------

--- Set $0 (or var) to the next input record from the current input file.
--  This form of getline shall set the NF, NR, and FNR variables.
--
--  @param[type=string,opt=@{env.FILENAME|FILENAME}] var
--    Set variable var to the next input record from the current input file.
--
--  @return[type=boolean]
--    Shall return true for successful input,
--    false for end-of-file and raise an error otherwise.
local function awkgetline(var)
	local info = fileinfo[_env.FILENAME]
	if info == nil then
		-- TODO check for file type
		local handle, msg = io.open(_env.FILENAME)
		if handle == nil then
			error(msg, -1)
		end
		info = {
			handle = handle,
			nr = 0
		}
		fileinfo[_env.FILENAME] = info
	end
	-- TODO read record delimited by RS
	local record = info.handle:read()
	if record == nil then
		fileinfo[_env.FILENAME] = nil
		local s, msg = pcall(io.close,info.handle)
		if not s then
			error(msg, -1)
		end
		return false
	elseif var then
		_env["var"] = record
	else
		_record[0] = record
	end
	info.nr = info.nr + 1
	_env.FNR = info.nr
	_env.NR = _env.NR + 1
	return true
end

local function awkprint(...)
	if (...) then
		-- FIXME implementation far from optimal
		local args = {...}
		local stab = setmetatable({}, {
			__index = function(_,k) return tostring(args[k]) end,
			__len = function() return #args end
		})
		io.stdout:write(table.concat(stab, _env.OFS), _env.ORS)
	else
		io.stdout:write(_record[0], _env.ORS)
	end
end

local function awkclose(...)
	-- TODO add proper file handling
	error("close: not implemented", -1)
end

local function awksystem(...)
	-- TODO implement
	error("system: not implemented", -1)
end

-----------------------------------------------------------
-- AWK INTERNALS
-----------------------------------------------------------

local function getlineloop()
	while awkgetline() do
		for _,action in ipairs(actions) do
			action()
		end
	end
	return 'nextfile'
end

-----------------------------------------------------------
-- COMMAND LINE INTERFACE
-----------------------------------------------------------

do
	local tbl = actions
	for _,v in ipairs(arg) do
		if v == "--" then
			tbl = _env.ARGV
		else
			table.insert(tbl, v)
		end
	end
end

-----------------------------------------------------------
-- SETUP
-----------------------------------------------------------

_env.close = awkclose
_env.coroutine = _G.coroutine
_env.F = _record
_env.math = _G.math
_env.print = awkprint
_env.require = _G.require
_env.string = _G.string
_env.system = awksystem
_env.table = _G.table
_env.ARGC = #_env.ARGV

for n,f in pairs(awkstr) do
	_env[n] = f
end

if warn == nil then
	-- luacheck:ignore 121
	warn = function(...) io.stderr:write("warning: ", ..., "\n") end
else
	warn("@on")
end

-- compile actions
for i=1,#actions do
	local action = assert(load(actions[i]))
	setfenv(action, _env)
	actions[i] = action
end

-----------------------------------------------------------
-- MAIN LOOP
-----------------------------------------------------------
local stat, yield, data
for i=1,_env.ARGC do
	_env.FILENAME = _env.ARGV[i]
	if _env.FILENAME and _env.FILENAME ~= "" then
		local body = coroutine.wrap(getlineloop)
		while true do
			stat, yield, data = pcall(body)
			if (not stat) then
				error(yield, -1)
			end
			if yield == "next" then
				body = coroutine.wrap(getlineloop)
			elseif yield == "nextfile" then
				break
			elseif yield == "exit" then
				break
			else
				warn(string.format("unknown yield value: %s", yield))
			end
		end
		if yield == "exit" then
			break
		end
	end
end
os.exit(data or 0)