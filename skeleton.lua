#!/usr/bin/env lua

-- @Author: Oliver Zimmer
-- @Date:   2023-02-20 11:22:41
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-02-21 09:32:15

local awkenv = require "awk.env"
local awkstr = require "awk.string"

local actions = {}
local infiles = {}

-----------------------------------------------------------
-- COMMAND LINE INTERFACE
-----------------------------------------------------------

do
	local tbl = actions
	for _,v in ipairs(arg) do
		if v == "--" then
			tbl = infiles
		else
			table.insert(tbl, v)
		end
	end
end

-----------------------------------------------------------
-- FUNCTION DEFINITIONS
-----------------------------------------------------------

local _env, _record

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

-- awkgetline([var]) Set var (or $0) from the next input record; set NR, FNR.
local function awkgetline(var)
	local info = infiles[_env.FILENAME]
	if info == nil then
		local handle, msg = io.open(_env.FILENAME)
		if handle == nil then
			error(msg, -1)
		end
		info = {
			handle = handle,
			nr = 0
		}
		infiles[_env.FILENAME] = info
	end
	local record = info.handle:read()
	if record == nil then
		infiles[_env.FILENAME] = nil
		local s, msg = pcall(io.close,info.handle)
		if not s then
			error(msg, -1)
		end
		coroutine.yield("nextfile")
	elseif var then
		_env["var"] = record
	else
		_record[0] = record
	end
	info.nr = info.nr + 1
	_env.FNR = info.nr
	_env.NR = _env.NR + 1
end

local function awkprint(...)
	if (...) then
		-- FIXME replace lazy implemenation
		local args = {...}
		local stab = setmetatable({}, {
			__index = function(_,k) return args[k] and tostring(args[k]) end,
			__len = function() return #args end
		})
		io.stdout:write(table.concat(stab, _env.OFS), _env.ORS)
	else
		io.stdout:write(_record[0], _env.ORS)
	end
end

local function awkprogram()
	while true do
		awkgetline()
		for _,action in ipairs(actions) do
			action()
		end
	end
end

-----------------------------------------------------------
-- SETUP
-----------------------------------------------------------

_env, _record = awkenv:new()
_env.F = _record
_env.table = _G.table
_env.string = _G.string
_env.math = _G.math
_env.require = _G.require
_env.coroutine = _G.coroutine
_env.print = awkprint
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
for _, filename in ipairs(infiles) do
	local body = coroutine.wrap(awkprogram)
	_env.FILENAME = filename
	while true do
		stat, yield, data = pcall(body)
		if (not stat) then
			error(yield, -1)
		end
		if yield == "next" then
			body = coroutine.wrap(awkprogram)
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
os.exit(data or 0)