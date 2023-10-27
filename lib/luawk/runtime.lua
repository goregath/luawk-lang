--- Luawk Runtime.
--
-- @usage require("luawk.runtime").run(name, program, env)
-- @module runtime
-- @see posix
-- @see gnu

local log = require 'luawk.log'
local utils = require 'luawk.utils'
local abort = utils.abort

local name = arg[0]:gsub("^(.*/)([^.]+).*$", "%2"):match("[^.]+") or "luawk"

local function atoi(v) return tonumber(v) or 0 end
local function incr(v) return atoi(v) + 1 end
local function isinf(v) return v == math.huge or v == -math.huge end
local function isnan(v) return v ~= v end

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

local ctxclass = {}

--- Generic action.
-- @return[2,type=true] state has been affected
function ctxclass:doaction(fn, ...)
    local ok, val = pcall(fn, ...)
    if ok and val == nil then
        return false
    elseif ok then
        -- return value is exit code
        self.status = "exit"
        self.code = val
    elseif val ~= self then
        abort("%s: error: %s\n", name, val)
    end
    return true
end

--- Special compound action for getline.
--  This action may trigger BEGINFILE and ENDFILE actions.
-- @return[2,type=true] state has been affected
ctxclass.dogetline = coroutine.wrap(function(self)
    local getline, filename, state, var
    local argc = atoi(self.env.ARGC)
    local nofile = true
    for i=1,argc do
        filename = self.env.ARGV[i]

        if i == argc and nofile then
            -- List contains no file arguments, default to "-" (stdin)
            filename, i = "-", argc -1
        elseif filename == nil or filename == "" then
            -- If the value of a particular element of ARGV is empty, skip over it.
            goto SKIP
        elseif type(filename) == "string" and filename:find("=") then
            -- If an argument matches the format of an assignment operand, this
            -- argument shall be treated as an assignment rather than a file argument.
            local k,v = filename:match("^([_%a][_%w]*)=(.*)$")
            if k then
                self.env[k] = v
                goto SKIP
            end
        end

        nofile = false
        self.env.FNR = 0
        self.env.FILENAME = filename
        self.env.ARGIND = i

        -- BEGINFILE
        for _, action in ipairs(self.program.BEGINFILE) do
            self.action = "BEGINFILE"
            if self:doaction(action) then
                if self.status == "nextfile" then
                    goto NEXTFILE
                else
                    goto END
                end
            end
        end

        -- TODO FIXME cleanup open file descriptors, best would be to user self.env.close()
        -- by calling the garbage collector we automatically close all dangling file descriptors
        collectgarbage()

        getline, state, var = failfast(self.env.getlines, filename)
        if not getline then
            abort("%s: error: %s\n", name, state)
        end

        for record, rt in wrapfail(getline), state, var do
            self.env[0] = record
            self.env.RT = rt
            self.env.NR = incr(self.env.NR)
            self.env.FNR = incr(self.env.FNR)
            coroutine.yield(false)
            if self.status == "nextfile" then
                goto NEXTFILE
            end
        end
        ::NEXTFILE::
        self.status = nil

        -- ENDFILE
        for _, action in ipairs(self.program.ENDFILE) do
            self.action = "ENDFILE"
            if self:doaction(action) then
                goto END
            end
        end

        ::SKIP::
    end
    self.action = "getline"
    self.status = "exit"

    ::END::
    -- never return, indicate end of all streams
    while true do
        coroutine.yield(true)
        self.action = "getline"
        self.status = "exit"
    end
end)

local function run(program, runenv)

    local ctx = setmetatable({
        action = "action",
        code = 0,
        env = runenv,
        program = program,
    }, {
        __index = ctxclass
    })

    function runenv.exit(n)
        ctx.status = "exit"
        if n then
            ctx.code = n
        end
        error(ctx, 0)
    end

    function runenv.next()
        ctx.status = "next"
        error(ctx, 0)
    end

    function runenv.nextfile()
        ctx.status = "nextfile"
        error(ctx, 0)
    end

    -- TODO real close(expr)

    function runenv.getline(...)
        -- getline duality
        if select('#', ...) == 0 then
            if ctx.action == "BEGINFILE" or ctx.action == "ENDFILE" then
                ctx.status = "getline"
                error(ctx, 0)
            end
            if ctx:dogetline() then
                -- TODO find a better indicator
                if ctx.status == "exit" and ctx.action == "getline" then
                    return false
                end
                error(ctx, 0)
            end
            return true
        end
        abort("%s: error: getline with expression is not implemented\n", name)
    end

    -- BEGIN
    for _, action in ipairs(program.BEGIN) do
        ctx.action = "BEGIN"
        if ctx:doaction(action) then
            goto END
        end
    end

    -- TODO ugly
    if #program.BEGINFILE + #program.main + #program.ENDFILE + #program.END == 0 then goto END end

    -- runenv.getline, runenv.close = memoize(runenv.getline)

    while true do
        if ctx:dogetline() then
            goto END
        end
        for _, action in ipairs(program.main) do
            ctx.action = "action"
            if ctx:doaction(action) then
                if ctx.status == "next" then
                    ctx.status = nil
                    goto NEXT
                end
                if ctx.status == "nextfile" then
                    goto NEXT
                end
                goto END
            end
        end
        ::NEXT::
    end

    ::END::
    for _, action in ipairs(program.END) do
        ctx.action = "END"
        if ctx:doaction(action) then
            if ctx.status == "exit" then break end
        end
    end

    if ctx.status ~= nil and ctx.status ~= "exit" then
        abort("%s: error: %s not allowed in %s\n", name, ctx.status, ctx.action)
    end

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

    return status
end

return {
    run = run
}
