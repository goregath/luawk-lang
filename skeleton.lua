#!/usr/bin/env lua

local getopt = require 'posix.unistd'.getopt
local basename = require 'posix.libgen'.basename
local awkenv = require 'awk.env'
local awkstr = require 'awk.string'
local awkmath = require 'awk.math'
local awkgrammar = require 'awk.grammar'

local name = basename(arg[0])
local fileinfo = {}
local _env, _record = awkenv:new()
local program = {}
local program_mt = {
	__call = function(tab,tag)
		local list = tag and tab[tag] or tab.actions
		for _,fn in ipairs(list) do
			fn()
		end
	end
}

-----------------------------------------------------------
-- UTILITIES
-----------------------------------------------------------

--- Compatibility layer setfenv() for Lua 5.2+.
--  Taken from Penlight Lua Libraries (lunarmodules/Penlight).
local setfenv = _G.setfenv or function(f, t)
	local var
	local up = 0
	repeat
		up = up + 1
		var = debug.getupvalue(f, up)
	until var == '_ENV' or var == nil
	if var then
		debug.upvaluejoin(f, up, function() return var end, 1) -- use unique upvalue
		debug.setupvalue(f, up, t)
	end
	if f ~= 0 then return f end
end

local function abort(...)
	io.stderr:write(string.format(...))
	os.exit(1)
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
-- COMMAND LINE INTERFACE
-----------------------------------------------------------

do
	local sources = {}
	local loadstring = _G.loadstring or _G.load
	local function usage(handle)
		handle:write(table.concat {
			"Usage: ", name, " [-F value] [-v var=value] [--] 'program' [file ...]\n",
			"       ", name, " [-F value] [-v var=value] [-f file] [--] [file ...]\n",
			"\n",
		})
	end
	local function help(handle)
		usage(handle)
		handle:write(table.concat {
			"	-f file        Program text is read from file instead of from the command line.\n",
			"	-F value       Sets the field separator, FS, to value.\n",
			"	-v var=value   Assigns value to program variable var.\n",
			"\n",
		})
	end
	local function compile(src, srcname)
		local chunk, msg = loadstring(src, srcname)
		if not chunk then
			abort('%s: %s: %s\n', name, srcname, msg)
		end
		setfenv(chunk, _env)
		return chunk
	end
	local last_index = 1
	for r, optarg, optind in getopt(arg, 'hf:F:v:') do
		if r == '?' then
			usage(io.stderr)
			abort('%s: invalid option: %s\n', name, arg[optind-1])
		end
		last_index = optind
		if r == 'h' then
			help(io.stdout)
			os.exit(0)
		elseif r == 'F' then
			-- TODO apply after any BEGIN rule(s) have been run
			_env.FS = optarg
		elseif r == 'v' then
			-- TODO apply after any BEGIN rule(s) have been run
			local k,v = string.match(optarg, "^(%w+)=(.*)$")
			if k and v then
				_env[k] = v
			else
				abort('%s: invalid argument: %s\n', name, optarg)
			end
		elseif r == 'f' then
			local stat, handle, msg
			handle, msg = io.open(optarg)
			if handle == nil then
				abort('%s: %s\n', name, msg)
			end
			local src = handle:read("*a")
			table.insert(sources, src)
			stat, msg = pcall(io.close, handle)
			if not stat then
				abort('%s: %s\n', name, msg)
			end
		end
	end
	if arg[last_index] == '--' then
		last_index = last_index + 1
	end
	if #sources == 0 then
		-- first argument is the program
		local src = arg[last_index]
		if not src then
			usage(io.stderr)
			abort('%s: program expected\n', name)
		end
		table.insert(sources, src)
		last_index = last_index + 1
	end
	for i = last_index, #arg do
		table.insert(_env.ARGV, arg[i])
	end
	local source = table.concat(sources, '\n')
	local parsed, msg = awkgrammar.parse(source)
	if not parsed then
		abort('%s: %s\n', name, msg)
	end
	for _,list in pairs(parsed.program) do
		for at,src in ipairs(list) do
			if type(src) == 'table' then
				-- TODO implement action compilation
				if #src == 2 then
					list[at] = compile(string.format(
						'if not (%s) then return end %s',
						table.unpack(src)
					))
				elseif #src == 3 then
					abort('not implemented')
				else
					abort('%s: invalid pattern or action\n', name)
				end
			else
				list[at] = compile(src)
			end
		end
	end
	program = setmetatable(parsed.program, program_mt)
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
_env.ARGC = #_env.ARGV+1

for n,f in pairs(awkstr) do
	_env[n] = f
end

for n,f in pairs(awkmath) do
	_env[n] = f
end

if warn == nil then
	-- luacheck:ignore 121
	warn = function(...)
		io.stderr:write("warning: ", ...)
		io.stderr:write("\n")
	end
else
	warn("@on")
end

-----------------------------------------------------------
-- MAIN LOOP
-----------------------------------------------------------

local exitcode = 0

local function singlerun(section)
	program(section)
end

local function loop()
	while true do
		program('actions')
		coroutine.yield("next")
	end
end

local function specialaction(action)
	local runner = coroutine.create(singlerun)
	repeat
		local stat, yield, data = coroutine.resume(runner, action)
		if (not stat) then
			abort("%s: error: %s\n", name, yield)
		end
		if yield == "next" or yield == "nextfile" then
			abort("%s: error: '%s' used in BEGIN action\n", name, yield)
		elseif yield == "exit" then
			exitcode = data or exitcode
			return false
		end
	until coroutine.status(runner) == "dead"
	return true
end

if not specialaction('BEGIN') then
	goto END
end

for i=1,_env.ARGC-1 do
	_env.FILENAME = _env.ARGV[i]
	-- If the value of a particular element of ARGV is empty (""), awk skips over it.
	-- TODO handle FILENAME "-" (stdin)
	if _env.FILENAME and _env.FILENAME ~= "" then
		local runner = coroutine.create(loop)
		while awkgetline() do
			local stat, yield, data = coroutine.resume(runner)
			if (not stat) then
				abort("%s: error: %s\n", name, yield)
			end
			if yield == "next" then
				goto NEXT
			elseif yield == "nextfile" then
				goto NEXTFILE
			elseif yield == "exit" then
				exitcode = data or exitcode
				goto END
			else
				warn(string.format("unknown yield value: %s", yield))
			end
			::NEXT::
		end
	end
	::NEXTFILE::
end
::END::

specialaction('END')
os.exit(tonumber(exitcode) or 1)