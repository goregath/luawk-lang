#!/usr/bin/env lua

--- Luawk interpreter.
--
--  @usage
--      Usage: luawk.lua [-F value] [-v var=value] [--] 'program' [file ...]
--             luawk.lua [-F value] [-v var=value] [-f file] [--] [file ...]
--
--          -f file        Program text is read from file instead of the command line.
--          -F value       Sets the field separator, FS, to value.
--          -v var=value   Assigns value to program variable var.
--
-- @script luawk

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
        "   -f file        Program text is read from file instead of the command line.\n",
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

local function version(handle)
    local ver = "0.1"
    handle:write(name, " ", ver, "\n")
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

local oneliner = true
local sources = {}
local runenv = librunenv.new(_G)

local function set_property(optarg)
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
            return false
        end
    else
        return false
    end
end

local function set_var(optarg)
    local k,v = string.match(optarg, "^([_%a][_%w]*)=(.*)$")
    if k and v then
        runenv[k] = v
    else
        return false
    end
end

local function set_program(optarg)
    local stat, handle, msg
    handle, msg = io.open(optarg)
    if handle == nil then
        abort('%s: %s\n', name, msg)
    end
    local src = handle:read("*a")
    table.insert(sources, { optarg, src })
    stat = pcall(io.close, handle)
    if not stat then
        return false
    end
    oneliner = false
end

local function set_library(optarg)
    -- TODO add to usage string
    local src = librequire(optarg)
    if not src then
        abort('%s: library not found: %s\n', name, optarg)
    end
    table.insert(sources, { optarg, src })
end

local function set_cmdstring(optarg)
    -- TODO add to usage string
    table.insert(sources, { "cmdline", optarg })
end

local flags = {
    h = function() help(io.stdout) os.exit() end,
    V = function() version(io.stdout) os.exit() end,
}

local options = {
    F = function(sep) runenv.FS = sep end,
    W = set_property,
    e = set_cmdstring,
    f = set_program,
    l = set_library,
    v = set_var,
}

local long_options = {
    ["--help"] = "-h",
    ["--version"] = "-V",
}

local function argparse(argv)
    local last_index
    local nextarg = coroutine.wrap(function()
        for i = 1, #argv do
            last_index = i
            coroutine.yield(argv[i])
        end
    end)
    for a in nextarg do
        if a:match("^%-%-.+") then
            if long_options[a] then
                a = long_options[a]
            else
                abort('%s: unknown option: `%s`\n', name, a)
            end
        end
        if a:match("^%-[^%-]") then
            local p = 2
            for c in a:sub(2):gmatch(".") do
                p = p + 1
                if options[c] then
                    local oa = a:sub(p)
                    if #oa == 0 then
                        oa = nextarg()
                    end
                    if not oa then
                        abort('%s: missing argument: `-%s`\n', name, c)
                    end
                    if options[c](oa) == false then
                        abort('%s: invalid argument: `-%s %q`\n', name, c, oa)
                    end
                    break
                elseif flags[c] then
                    if flags[c]() == false then
                        abort('%s: invalid flag: `-%s`\n', name, c)
                    end
                else
                    abort('%s: unknown option: `%s`\n', name, c)
                end
            end
        else
            if a == "--" then
                last_index = last_index + 1
            end
            break
        end
    end
    return last_index
end

local last_index = argparse(arg)

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

-- TODO add test
-- Let ARGV be a proxy to arg
local argc = #arg - last_index + 1
runenv.ARGV = setmetatable({}, {
    __newindex = function(t,k,v)
        if tonumber(k) then
            rawset(t,k,v)
            if v == nil and k == argc then
                argc = argc - 1
            else
                argc = math.max(argc, k)
            end
        end
    end,
    __index = function(_,k)
        if tonumber(k) then
            local i = last_index + k - 1
            if i <= #arg then
                return arg[i]
            elseif k <= argc then
                return ""
            end
        end
    end,
    __len = function() return argc end,
    __metatable = false,
})
runenv.ARGC = #runenv.ARGV

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

erde.load({
    keep_traceback = false,
    disable_source_maps = false,
})
luawktype.enable()

local status = runtime.run(program, runenv)
os.exit(status)
