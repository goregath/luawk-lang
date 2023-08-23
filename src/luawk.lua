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

local compat53 = require 'luawk.compat53'
local load = compat53.load
local log = require 'luawk.log'
local utils = require 'luawk.utils'
local abort = utils.abort
local acall = utils.acall

local erde = require "erde"

local luawktype = require "luawk.type"
local runtime = require "luawk.runtime"
local librunenv = require 'luawk.environment.gnu'

local name = arg[0]:gsub("^(.*/)([^.]+).*$", "%2"):match("[^.]+") or "luawk"

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
        "   -W regex=module\n",
        "   -W log=level\n",
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

local erdeopts = {
    lua_target = compat53.version,
    bitlib = compat53.version_normalized < 503 and 'luawk.compat53' or nil,
    alias = "",
}
local function compile(env, src, srcname)
    log.trace("%s: %s\n", srcname, src)
    local ok, lsrc = pcall(erde.compile, src, erdeopts)
    if not ok then
        lsrc = lsrc:gsub("^:%d%s*:%s*", "")
        abort('%s: error: %s\n', name, lsrc)
    end
    log.trace("%s: %s\n", srcname, lsrc)
    local chunk, msg = load(lsrc, srcname, "t", env)
    if not chunk then
        msg = msg:gsub("^%b[]", "")
        abort('%s: [%s]%s\n', name, src, msg)
    end
    return chunk
    -- TODO maybe needed for stateful chunks
    -- for i=1,2 do
    --     if not debug.getupvalue(chunk, i) then
    --         debug.setupvalue(chunk, i, "_")
    --         return chunk
    --     end
    -- end
    -- abort('%s: %s\n', name, "failed to register upvalue")
end

local function rangepattern(env, e1, e2, a)
    local on = false
    local fe1 = compile(env, string.format("return (%s)+0!=0", e1), "begin-pattern")
    local fe2 = compile(env, string.format("return (%s)+0!=0", e2), "end-pattern")
    local act = compile(env, a, "action")
    return function()
        if on then
            if fe2() then
                on = false
            end
            act()
        elseif fe1() then
            on = not fe2()
            act()
        end
    end
end

-- ---------------------------------------------------------
-- COMMAND LINE INTERFACE
-- ---------------------------------------------------------

local sources = {}
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
            if k == "regex" then
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
local runenv = librunenv.new(_G)
-- getopt stage 2 - runenv flags and options
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
        runenv.FS = optarg
    elseif r == 'v' then
        local k,v = string.match(optarg, "^([_%a][_%w]*)=(.*)$")
        if k and v then
            runenv[k] = v
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
runenv.ARGV[1] = "-"
-- remaining arguments are files
for i = last_index, #arg do
    runenv.ARGV[i-last_index+1] = arg[i]
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
                        list[at] = compile(runenv, src[2], "action")
                    else
                        list[at] = compile(runenv, string.format(
                            'if((%s)+0!=0){%s}', src[1], src[2]
                        ), "pattern-action")
                    end
                elseif #src == 3 then
                    -- pattern, pattern, action
                    list[at] = rangepattern(runenv, table.unpack(src))
                else
                    abort('%s: invalid pattern or action\n', name)
                end
            else
                list[at] = compile(runenv, src, "special-pattern-action")
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

-- ---------------------------------------------------------
-- MAIN LOOP
-- ---------------------------------------------------------

program = setmetatable(program, program_mt)
runenv.ARGV[0] = arg[0]
runenv.ARGC = #runenv.ARGV+1

-- Support for ${expr} grammar
-- ${expr} evaluates to _ENV^{expr}
local runmt = getmetatable(runenv) or {}
setmetatable(runenv, runmt)
function runmt:__pow(e)
    return self[e]
end

erde.load({
    keep_traceback = false,
    disable_source_maps = false,
})
luawktype.enable()

local status = runtime.run(program, runenv)
os.exit(status)