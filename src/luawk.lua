#!/usr/bin/env lua

--- Luawk interpreter.
--
--  @usage
--      Usage: luawk.lua [-F value] [-v var=value] [--] 'program' [file ...]
--             luawk.lua [-F value] [-v var=value] [-f file] [--] [file ...]
--
--          -f file        Program text is read from file instead of from the command line.
--          -F value       Sets the field separator, FS, to value.
--          -v var=value   Assigns value to program variable var.
--
-- @script luawk

local getopt = require 'posix.unistd'.getopt

local log = require 'luawk.log'
local libruntime = require 'luawk.runtime'
local utils = require 'luawk.utils'
local abort = utils.abort
local setfenv = utils.setfenv

local name = string.gsub(arg[0], "(.*/)(.*)", "%2")
local runtime = _G
local rangestate = {}
local program = {
	BEGIN = {},
	END = {},
	BEGINFILE = {},
	ENDFILE = {},
	main = {}
}
local program_mt = {
	__call = function(tab,tag)
		local list = tag and tab[tag] or tab.main
		for _,fn in ipairs(list) do
			fn()
		end
	end
}

-- ---------------------------------------------------------
-- UTILITIES
-- ---------------------------------------------------------

local optstring = ':hf:F:v:W:'

local function usage(handle)
	handle:write(table.concat {
		"Usage: ", name, " [-W option] [-F value] [-v var=value] [--] 'program' [file ...]\n",
		"       ", name, " [-W option] [-F value] [-v var=value] [-f file] [--] [file ...]\n",
		"\n",
	})
end

local function help(handle)
	usage(handle)
	handle:write(table.concat {
		"	-f file        Program text is read from file instead of from the command line.\n",
		"	-F value       Sets the field separator, FS, to value.\n",
		"	-v var=value   Assigns value to program variable var.\n",
		"	-W flag\n",
		"	-W var=value\n",
		"\n",
	})
end

-- ---------------------------------------------------------
-- AWK FUNCTIONS AND KEYWORDS
-- ---------------------------------------------------------

--- @function close
local function awkclose(...)
	-- TODO add proper file handling
	abort("close: not implemented\n")
end

--- @function system
local function awksystem(...)
	-- TODO implement
	abort("system: not implemented\n")
end

-- ---------------------------------------------------------
-- COMMAND LINE INTERFACE
-- ---------------------------------------------------------

do
	local sources = {}
	local loadstring = _G.loadstring or _G.load
	local function compile(src, srcname)
		local chunk, msg = loadstring(src, srcname)
		if not chunk then
			msg = msg:gsub("^%b[]", "")
			abort('%s: [%s]%s\n', name, src, msg)
		end
		setfenv(chunk, runtime)
		return chunk
	end
	-- getopt stage 1 - special flags and options
	for r, optarg, optind in getopt(arg, optstring) do
		if r == ':' then
			usage(io.stderr)
			abort('%s: missing argument: %s\n', name, arg[optind-1])
		elseif r == 'h' then
			help(io.stdout)
			os.exit(0)
		elseif r == 'W' then
			local k,v = string.match(optarg, "^(%w+)=?(.*)$")
			if k then
				if k == "runtime" then
					libruntime =
						utils.requireany(v, "luawk.runtime." .. v)
						or abort('%s: cannot find runtime for %q\n', name, v)
				elseif k == "regex" then
					package.loaded["luawk.regex"] =
						utils.requireany(v, "rex_" .. v)
						or abort('%s: cannot find regex library for %q\n', name, v)
				elseif k == "loglevel" then
					-- TODO check for valid name
					log.level = v
				else
					abort('%s: invalid argument: %s\n', name, optarg)
				end
			else
				abort('%s: invalid argument: %s\n', name, optarg)
			end
		end
	end
	-- initialiaze final runtime implementaton
	runtime = libruntime.new(runtime)
	-- getopt stage 2 - runtime flags and options
	local last_index = 1
	for r, optarg, optind in getopt(arg, optstring) do
		if r == '?' then
			usage(io.stderr)
			abort('%s: invalid option: %s\n', name, arg[optind-1])
		end
		if r == ':' then
			usage(io.stderr)
			abort('%s: missing argument: %s\n', name, arg[optind-1])
		end
		last_index = optind
		if r == 'F' then
			-- TODO apply after any BEGIN rule(s) have been run
			runtime.FS = optarg
		elseif r == 'v' then
			-- TODO apply after any BEGIN rule(s) have been run
			local k,v = string.match(optarg, "^(%w+)=(.*)$")
			if k and v then
				runtime[k] = v
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
			table.insert(sources, { optarg, src })
			stat, msg = pcall(io.close, handle)
			if not stat then
				abort('%s: %s\n', name, msg)
			end
		end
	end
	-- handle arguments
	runtime.ARGV[1] = "-"
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
		table.insert(sources, { "cmdline", src })
		last_index = last_index + 1
	end
	-- remaining arguments are files
	for i = last_index, #arg do
		runtime.ARGV[i-last_index+1] = arg[i]
	end
	local awkgrammar = require 'luawk.lang.grammar'
	-- compile sources
	for _,srcobj in ipairs(sources) do
		local label, source = table.unpack(srcobj)
		local parsed, msg, _, lineno, col = awkgrammar.parse(source)
		if not parsed then
			if parsed == false then
				local line
				local l = 1
				for str in string.gmatch(source, "[^\n]*") do
					if l == lineno then
						line = str
						break
					end
					l = l + 1
				end
				line = line:gsub("%s", "\x20")
				local prefix = string.format('%s: %s:%d:%d: ', name, label, lineno, col)
				abort(
					'%s%s\n%'..(#prefix+(col-1))..'s %s\n',
					prefix, line, "^", msg
				)
			else
				abort('%s: %s: %s\n', name, label, msg)
			end
		end
		for _,list in pairs(parsed.program) do
			for at,src in ipairs(list) do
				if type(src) == 'table' then
					if #src == 2 then
						-- pattern, action
						if type(src[1]) == "boolean" and src[1] then
							list[at] = compile(src[2], "action")
						else
							list[at] = compile(string.format(
								'if %s then %s end',
								table.unpack(src)
							), "pattern-action")
						end
					elseif #src == 3 then
						-- pattern, pattern, action
						-- FIXME
						-- TODO refactor, matching twice could be expensive
						rangestate[at] = false
						list[at] = compile(string.format(
							'if coroutine.yield("x-range-on",%d,%s,%s) then %s end',
							at, table.unpack(src)
						), "range-pattern-action")
					else
						abort('%s: invalid pattern or action\n', name)
					end
				else
					list[at] = compile(src, "special-pattern-action")
				end
			end
		end
		for section,actions in pairs(parsed.program) do
			local tbl = program[section]
			for _,action in ipairs(actions) do
				table.insert(tbl, action)
			end
		end
	end
	program = setmetatable(program, program_mt)
	runtime.ARGV[0] = arg[0]
	runtime.ARGC = #runtime.ARGV+1
end

-- ---------------------------------------------------------
-- SETUP
-- ---------------------------------------------------------

-- runtime.close = awkclose
-- runtime.system = awksystem

-- ---------------------------------------------------------
-- MAIN LOOP
-- ---------------------------------------------------------

local exitcode = 0

local function singlerun(section)
	program(section)
end

local function loop()
	while runtime.getline() do
		program('main')
	end
	coroutine.yield("nextfile")
end

local function specialaction(action)
	local runner = coroutine.create(singlerun)
	repeat
		local stat, yield, d1, d2, d3 = coroutine.resume(runner, action)
		if (not stat) then
			abort("%s: error: %s\n", name, yield)
		end
		if yield == "next" or yield == "nextfile" then
			abort("%s: error: '%s' used in BEGIN action\n", name, yield)
		elseif yield == "exit" then
			exitcode = d1 or exitcode
			return false
		elseif yield ~= nil then
			log.warn("unknown yield value: %s (%s,%s,%s)", yield, d1, d2, d3)
		end
	until coroutine.status(runner) == "dead"
	return true
end

if not specialaction('BEGIN') then
	goto END
end

for i=1,runtime.ARGC-1 do
	runtime.FILENAME = runtime.ARGV[i]
	if not specialaction('BEGINFILE') then
		goto END
	end
	-- If the value of a particular element of ARGV is empty (""), awk skips over it.
	if runtime.FILENAME and runtime.FILENAME ~= "" then
		local runner = coroutine.create(loop)
		local d0 = nil
		repeat
			local stat, yield, d1, d2, d3 = coroutine.resume(runner, d0)
			d0 = nil
			if (not stat) then
				abort("%s: error: %s\n", name, yield)
			end
			if yield == "next" then
				runner = coroutine.create(loop)
				goto NEXT
			elseif yield == "nextfile" then
				goto NEXTFILE
			elseif yield == "exit" then
				exitcode = d1 or exitcode
				goto END
			elseif yield == "x-range-on" then
				d0 = rangestate[d1]
				-- FIXME range not handled properly
				-- $ printf '%s\n' {1..9} > seq.txt
				-- $ awk '/9/,/1/' seq.txt seq.txt
				-- 9
				-- 1
				-- 9
				-- $ luawk '/9/,/1/' seq.txt seq.txt
				-- 9
				-- 9
				if d0 == true then
					if d3 then d0 = false end
				end
				if d0 == false then
					if d2 then d0 = true end
				end
				rangestate[d1] = d0
			elseif yield ~= nil then
				log.warn("unknown yield value: %s (%s,%s,%s)", yield, d1, d2, d3)
			end
			::NEXT::
		until coroutine.status(runner) == "dead"
	end
	::NEXTFILE::
	if not specialaction('ENDFILE') then
		goto END
	end
	-- TODO refactor
	-- FNR==2 { nextfile } 1' /etc/passwd /etc/passwd -> should print two lines
	-- TODO ?? fileinfo[runtime.FILENAME] = nil
end
::END::

specialaction('END')
os.exit(tonumber(exitcode) or 1)
