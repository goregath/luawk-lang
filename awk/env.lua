--- AWK environment.
-- @classmod env
-- @alias env

local awkstring = require "awk.string"

local function makero(...)
    local ro = {}
    for _, v in ipairs {...} do
        ro[v] = 1
    end
    return ro
end

--- @table defaults
-- @field ARGC
--  The number of elements in the @{ARGV} array.
-- @field FILENAME
--  A pathname of the current input file. Inside a _BEGIN_ action the value is
--  undefined. Inside an _END_ action the value shall be the name of the last
--  input file processed.
-- @field FNR
--  The ordinal number of the current record in the current file. Inside a _BEGIN_
--  action the value shall be zero. Inside an _END_ action the value shall be the
--  number of the last record processed in the last file processed.

local recordvar = "F"
--- default environment
local env = {}
local virtenv = {}
--- environment metatable
local env_mt = {}
--- set of readonly names
local envro = makero( "ENVIRON", recordvar )

--- The number of elements in the @{ARGV} array.
env.ARGC = 0

--- An array of command line arguments, excluding options and the program
--  argument, numbered from zero to @{ARGC}-1. The arguments in @{ARGV} can be
--  modified or added to; @{ARGC} can be altered. As each input file ends, awk
--  shall treat the next non-null element of @{ARGV}, up to the current value of
--  @{ARGC}-1, inclusive, as the name of the next input file. Thus, setting an
--  element of @{ARGV} to null means that it shall not be treated as an input
--  file. The name `'-'` indicates the standard input. If an argument matches the
--  format of an assignment operand, this argument shall be treated as an
--  assignment rather than a file argument.
env.ARGV = {}

--- The printf format for converting numbers to strings (except for output
--  statements, where @{OFMT} is used); `"%.6g"` by default.
env.CONVFMT = "%.6g"

--- An array representing the value of the environment, as described in the exec
--  functions defined in the System Interfaces volume of POSIX.1-2017. The
--  indices of the array shall be strings consisting of the names of the
--  environment variables, and the value of each array element shall be a
--  string consisting of the value of that variable. If appropriate, the
--  environment variable shall be considered a numeric string (see Expressions
--  in awk); the array element shall also have its numeric value. In all cases
--  where the behavior of awk is affected by environment variables
--  (including the environment of any commands that awk executes via the system
--  function or via pipeline redirections with the print statement, the printf
--  statement, or the getline function), the environment used shall be the
--  environment at the time awk began executing; it is implementation-defined
--  whether any modification of @{ENVIRON} affects this environment.
env.ENVIRON = setmetatable({}, {
    __index = function(_, k) return os.getenv(k) end,
    -- TODO fake setenv
    __newindex = error
})

--- A pathname of the current input file. Inside a _BEGIN_ action the value is
--  undefined. Inside an _END_ action the value shall be the name of the last
--  input file processed.
env.FILENAME = 0

--- The ordinal number of the current record in the current file. Inside a _BEGIN_
--  action the value shall be zero. Inside an _END_ action the value shall be the
--  number of the last record processed in the last file processed.
env.FNR = 0

--- Input field separator regular expression; a _space_ by default.
env.FS = '\32'

--- The number of fields in the current record. Inside a _BEGIN_ action, the use
--  of @{NF} is undefined unless a getline function without a var argument is
--  executed previously. Inside an _END_ action, @{NF} shall retain the value it had
--  for the last record read, unless a subsequent, redirected, getline function
--  without a var argument is performed prior to entering the _END_ action.
env.NF = 0

--- The ordinal number of the current record from the start of input. Inside a
--  _BEGIN_ action the value shall be zero. Inside an _END_ action the value shall
--  be the number of the last record processed.
env.NR = 0

--- The printf format for converting numbers to strings in output statements
--  (see Output Statements); `"%.6g"` by default. The result of the conversion is
--  unspecified if the value of @{OFMT} is not a floating-point format
--  specification.
env.OFMT = "%.6g"

--- The print statement output field separator; _space_ by default.
env.OFS = '\32'

--- The print statement output record separator; a _newline_ by default.
env.ORS = '\n'

--- The length of the string matched by the match function.
env.RLENGTH = 0

--- The first character of the string value of @{RS} shall be the input record
--  separator; a _newline_ by default. If @{RS} contains more than one character,
--  the results are unspecified. If @{RS} is null, then records are separated by
--  sequences consisting of a _newline_ plus one or more blank lines, leading
--  or trailing blank lines shall not result in empty records at the beginning
--  or end of the input, and a _newline_ shall always be a field separator, no
--  matter what the value of @{FS} is.
env.RS = '\n'

--- The starting position of the string matched by the match function, numbering
--  from 1. This shall always be equivalent to the return value of the match
--  function.
env.RSTART = 0

-- local f_mt = {}
-- env.F = setmetatable({}, f_mt)

-- function f_mt.__len(t)
--     -- print(t.NF)
--     return tonumber(t.NF or 0) or 0
-- end

-- function env_mt.__index(t,k)
--     -- if v == nil then v = "" end
--     if envro[k] then
--         error("attempt to modify a read-only variable")
--     end
--     if k == "NF" then
--         return
--     return env[k]
-- end

-- function env_mt.__newindex(t,k,v)
--     if v == nil then v = "" end
--     if not envro[k] then
--         t[k] = v
--     end
-- end

-- TODO NF: error("NF set to negative value")
-- TODO recompute $1..$NF before accessing NF

--- Create a new environment
local function new(G)
    local global = G and setmetatable({}, { __index = G }) or {}
    local record = { nf = 0 }
    local recobj = {}
    local envobj = setmetatable(global, {
        __index = function(_,k)
            if k == "NF" then
                return record.nf
            end
            return env[k]
        end,
        __newindex = function(t,k,v)
            if envro[k] then
                error("attempt to modify a read-only variable")
            end
            if k == "NF" then
                record.nf = math.modf(tonumber(v) or 0)
                if record.nf < 0 then
                    error("NF set to negative value")
                end
                -- clear fields after NF
                for i=record.nf+1,#record do
                    record[i] = nil
                end
                -- immediately recompute $0
                record[0] = nil
                local _ = recobj[0]
            elseif not envro[k] then
                rawset(t, k, v)
            end
        end
    })
    setmetatable(recobj, {
        __len = function()
            return record.nf
        end,
        __index = function(_,k)
            local idx = math.modf(tonumber(k) or 0)
            local ofs = envobj.OFS ~= nil and tostring(envobj.OFS) or env.OFS
            if idx < 0 then error("access to negative field") end
            if idx > record.nf then return nil end
            if idx == 0 and record[0] == nil then
                -- recompute $0
                record[0] = table.concat(recobj, ofs, 1, record.nf)
            end
            return record[idx] or ""
        end,
        __newindex = function(_,k,v)
            local idx = math.modf(tonumber(k) or 0)
            if idx < 0 then error("access to negative field") end
            if idx > 0 then
                -- set field $(idx)
                record[idx] = v ~= nil and tostring(v) or ""
                -- recompute $0
                record[0] = nil
                if idx > record.nf then record.nf = idx end
            elseif idx == 0 then
                -- set record $0
                record[0] = v and tostring(v) or ""
                -- compute fields $1..$NF
                record.nf = awkstring.split(v, record, envobj.FS ~= nil and tostring(envobj.FS) or env.FS)
            end
        end
    })
    rawset(envobj, recordvar, recobj)
    return envobj
end

--- @export
return {
    new = new
}