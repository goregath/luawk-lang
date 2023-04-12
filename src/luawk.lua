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
local acall = utils.acall

local name = arg[0]:gsub("^(.*/)([^.]+).*$", "%2"):match("[^.]+") or "luawk"
local runtime = _G
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

local optstring = ':he:f:F:l:v:W:'

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
        "   -f file        Program text is read from file instead of from the command line.\n",
        "   -F value       Sets the field separator, FS, to value.\n",
        "   -v var=value   Assigns value to program variable var.\n",
        "   -W flag\n",
        "   -W var=value\n",
        "\n",
        "   -W runtime=module\n",
        "   -W regex=module\n",
        "   -W loglevel=level\n",
        "\n",
    })
end

local function librequire(path)
    local var = name:gsub("%A", ""):upper()
    local env = os.getenv(var .. "_PATH") or "?.luawk"
    local lib = path:gsub("%.", "/")
    for file in env:gsub("%?", lib):gmatch("[^;]+") do
        local handle = io.open(file)
        if handle then
            local src = handle:read('a')
            handle:close()
            return src
        end
    end
    return nil
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
                    -- TODO refactor
                    local relib =
                        utils.requireany(v, "rex_" .. v)
                        or abort('%s: cannot find regex library for %q\n', name, v)
                    require("luawk.regex").find = relib.find
                    -- package.loaded["luawk.regex"] =
                    --     utils.requireany(v, "rex_" .. v)
                    --     or abort('%s: cannot find regex library for %q\n', name, v)
                elseif k == "log" then
                    acall(log.level, v)
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
    local oneliner = true
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
            runtime.FS = optarg
        elseif r == 'v' then
            local k,v = string.match(optarg, "^([_%a][_%w]*)=(.*)$")
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
            oneliner = false
        elseif r == 'l' then
            -- TODO add to usage string
            local src = librequire(optarg)
            if not src then
                abort('%s: library not found: %s\n', name, optarg)
            end
            table.insert(sources, { optarg, src })
        elseif r == 'e' then
            -- TODO add to usage string
            table.insert(sources, { "cmdline", optarg })
        end
    end
    -- handle arguments
    if arg[last_index] == '--' then
        last_index = last_index + 1
    end
    if oneliner then
        -- first argument is the program
        local src = arg[last_index]
        if not src then
            usage(io.stderr)
            abort('%s: program expected\n', name)
        end
        table.insert(sources, { "cmdline", src })
        last_index = last_index + 1
    end
    -- TODO should fallback to stdin: awk 1 a=1
    runtime.ARGV[1] = "-"
    -- remaining arguments are files
    for i = last_index, #arg do
        runtime.ARGV[i-last_index+1] = arg[i]
    end
    -- compile sources
    for _,srcobj in ipairs(sources) do
        local awkgrammar = require 'luawk.lang.grammar'
        local label, source = table.unpack(srcobj)
        local parsed, msg, _, lineno, col = awkgrammar.parse(source)
        -- TODO see FIXME in grammar
        package.loaded['luawk.lang.grammar'] = nil
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
                        abort("%s: range pattern not implemented\n", name)
                        -- rangestate[at] = false
                        -- list[at] = compile(string.format(
                        --     'if coroutine.yield("x-range-on",%d,%s,%s) then %s end',
                        --     at, table.unpack(src)
                        -- ), "range-pattern-action")
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
-- MAIN LOOP
-- ---------------------------------------------------------

local function atoi(v) return tonumber(v) or 0 end
local function incr(v) return atoi(v) + 1 end
local function isinf(v) return v == math.huge or v == -math.huge end
local function isnan(v) return v ~= v end
local ctx = { code = 0 }

local function failfast(...)
    local r = { pcall(...) }
    if not r[1] then
        abort("%s: error: %s\n", name, r[2])
    end
    return table.unpack(r, 2)
end

local function wrapfail(fn)
    return function(...)
        return failfast(fn, ...)
    end
end

local function memoize(fn)
    local mem = {}
    return function(arg1, ...)
        local dat = mem[arg1]
        if not dat then
            dat = { fn(arg1, ...) }
            mem[arg1] = dat
        end
        return table.unpack(dat)
    end, function(arg1)
        mem[arg1] = nil
    end
end

local function doaction(fn, ...)
    ctx.status = nil
    local ok, val = pcall(fn, ...)
    if ok and val == nil then
        return false
    elseif ok then
        -- return value is exit code
        ctx.status = "exit"
        ctx.code = val
    elseif val ~= ctx then
        abort("%s: error: %s\n", name, val)
    end
    return true
end

local dogetline = coroutine.wrap(function()
    local getline, state, var
    for i=1,atoi(runtime.ARGC)-1 do
        -- local getline, state, var
        local filename = runtime.ARGV[i]
        runtime.ARGIND = i

        if filename == nil or filename == "" then
            -- If the value of a particular element of ARGV is empty, skip over it.
            goto SKIP
        end

        if type(filename) == "string" and filename:find("=") then
            -- If an argument matches the format of an assignment operand, this
            -- argument shall be treated as an assignment rather than a file argument.
            local k,v = filename:match("^([_%a][_%w]*)=(.*)$")
            if k then
                runtime[k] = v
                goto SKIP
            end
        end

        runtime.FNR = 0
        runtime.FILENAME = filename

        -- BEGINFILE
        for _, action in ipairs(program.BEGINFILE) do
            if doaction(action) then
                if ctx.status == "nextfile" then
                    goto NEXTFILE
                else
                    goto END
                end
            end
        end

        -- TODO FIXME cleanup open file descriptors, best would be to user runtime.close()
        -- by calling the garbage collector we automatically close all dangling file descriptors
        collectgarbage()

        getline, state, var = failfast(runtime.getlines, filename)
        if not getline then
            abort("%s: error: %s\n", name, state)
        end

        for record, rt in wrapfail(getline), state, var do
            runtime[0] = record
            runtime.RT = rt
            runtime.NR = incr(runtime.NR)
            runtime.FNR = incr(runtime.FNR)
            coroutine.yield(false)
            if ctx.status == "nextfile" then
                goto NEXTFILE
            end
            ctx.status = nil
        end
        ::NEXTFILE::

        -- ENDFILE
        for _, action in ipairs(program.ENDFILE) do
            if doaction(action) then
                goto END
            end
        end

        ::SKIP::
    end

    ::END::
    -- never return, indicate end of all streams
    while true do
        coroutine.yield(true)
        ctx.status = "exit"
    end
end)

function runtime.exit(n)
    ctx.status = "exit"
    if n then
        ctx.code = n
    end
    error(ctx, 0)
end

function runtime.next()
    ctx.status = "next"
    error(ctx, 0)
end

function runtime.nextfile()
    ctx.status = "nextfile"
    error(ctx, 0)
end

-- TODO real close(expr)

function runtime.getline(...)
    -- getline duality
    if select('#', ...) == 0 then
        if dogetline() then
            error(ctx, 0)
        end
        return true
    end
    abort("%s: error: getline with expression is not implemented\n", name)
end

-- TODO getline in BEGIN should be handled, incl. BEGINFILE
-- gawk 'BEGIN { while (getline) print } BEGINFILE { print FILENAME }' /dev/fd/3 3<<<"a" /dev/fd/4 4<<<"b
-- /dev/fd/3
-- a
-- /dev/fd/4
-- b

-- BEGIN
for _, action in ipairs(program.BEGIN) do
    if doaction(action) then
        goto END
    end
end

-- TODO ugly
if #program.BEGINFILE + #program.main + #program.ENDFILE + #program.END == 0 then goto END end

-- runtime.getline, runtime.close = memoize(runtime.getline)

while true do
    if dogetline() then
        goto END
    end
    -- local ok, val = pcall(dogetline)
    -- -- print(ok, val, ctx.status)
    -- if not ok then
    --     -- if ctx.status == "nextfile" then goto NEXT end
    --     if ctx.status == "exit" then goto END end
    --     abort("%s: error: %s\n", name, val)
    -- end
    -- if not val then
    --     break
    -- end
    for _, action in ipairs(program.main) do
        if doaction(action) then
            if ctx.status == "next" then goto NEXT end
            if ctx.status == "nextfile" then goto NEXT end
            goto END
        end
    end
    ::NEXT::
    -- print("::NEXT::", ctx.status, ctx.code)
end

::END::
-- print("::END::", ctx.status, ctx.code)
for _, action in ipairs(program.END) do
    if doaction(action) then
        if ctx.status == "exit" then break end
    end
    -- local _, _status = pcall(action)
    -- if _status == ctx then
    --     status = ctx.status
    --     break
    -- elseif type(_status) == "number" then
    --     status = _status
    --     break
    -- elseif _status ~= nil then
    --     abort("%s: error: %s\n", name, _status)
    -- end
end

-- print("exit", ctx.status, ctx.code)

local status = ctx.code

-- expect nil, false or number
if status and type(status) ~= "number" or isnan(status) or isinf(status) then
    log.warn("unexpected status: %s\n", status)
end

-- coerce status to exit code
if     status == nil             then status = 0
elseif type(status) == "boolean" then status = status and 0 or 1
elseif type(status) ~= "number"  then status = math.modf(tonumber(status) or 1)
elseif isnan(status)             then status = 128
elseif isinf(status)             then status = 255
else                                  status = math.modf(status) end

os.exit(status)
