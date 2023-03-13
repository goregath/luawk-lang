--- POSIX AWK Runtime.
-- @usage require("luawk.runtime.posix").new(_G)
-- @runtime POSIX
-- @license MIT
-- @see awk(1p)

local stdlib = require 'posix.stdlib'
local setenv = stdlib.setenv
local getenv = stdlib.getenv

local regex = require 'luawk.regex'
local utils = require 'luawk.utils'
local log = require 'luawk.log'
local isarray = utils.isarray
local trim = utils.trim
local abort = utils.fail
local utf8charpattern = utils.utf8charpattern

local M = {}

--- The number of elements in the @{ARGV} array.
M.ARGC = 0

--- An array of command line arguments, excluding options and the program
--  argument, numbered from zero to @{ARGC}-1. The arguments in @{ARGV} can be
--  modified or added to; @{ARGC} can be altered. As each input file ends, awk
--  shall treat the next non-null element of @{ARGV}, up to the current value of
--  @{ARGC}-1, inclusive, as the name of the next input file. Thus, setting an
--  element of @{ARGV} to null means that it shall not be treated as an input
--  file. The name `'-'` indicates the standard input. If an argument matches the
--  format of an assignment operand, this argument shall be treated as an
--  assignment rather than a file argument.
M.ARGV = {}

--- The printf format for converting numbers to strings (except for output
--  statements, where @{OFMT} is used); `"%.6g"` by default.
M.CONVFMT = "%.6g"

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
--  @table ENVIRON
--  @label virtual
--  @see getenv(3)
--  @see setenv(3)
M.ENVIRON = setmetatable({}, {
    __index = function(_, k) return os.getenv(k) end,
    __newindex = function(_,k,v) setenv(k,v) end,
    __pairs = function() return pairs(getenv()) end,
})

--- A pathname of the current input file. Inside a _BEGIN_ action the value is
--  undefined. Inside an _END_ action the value shall be the name of the last
--  input file processed.
M.FILENAME = ""

--- The ordinal number of the current record in the current file. Inside a _BEGIN_
--  action the value shall be zero. Inside an _END_ action the value shall be the
--  number of the last record processed in the last file processed.
M.FNR = 0

--- Input field separator regular expression; a _space_ by default.
--  @see split
M.FS = '\32'

--- The number of fields in the current record. Inside a _BEGIN_ action, the use
--  of @{NF} is undefined unless a getline function without a var argument is
--  executed previously. Inside an _END_ action, @{NF} shall retain the value it had
--  for the last record read, unless a subsequent, redirected, getline function
--  without a var argument is performed prior to entering the _END_ action.
--  @class field
--  @label virtual
--  @name NF

--- The ordinal number of the current record from the start of input. Inside a
--  _BEGIN_ action the value shall be zero. Inside an _END_ action the value shall
--  be the number of the last record processed.
M.NR = 0

--- The printf format for converting numbers to strings in output statements
--  (see Output Statements); `"%.6g"` by default. The result of the conversion is
--  unspecified if the value of @{OFMT} is not a floating-point format
--  specification.
M.OFMT = "%.6g"

--- The print statement output field separator; _space_ by default.
M.OFS = '\32'

--- The print statement output record separator; a _newline_ by default.
M.ORS = '\n'

--- The length of the string matched by the match function.
M.RLENGTH = 0

--- The first character of the string value of @{RS} shall be the input record
--  separator; a _newline_ by default. If @{RS} contains more than one character,
--  the results are unspecified. If @{RS} is null, then records are separated by
--  sequences consisting of a _newline_ plus one or more blank lines, leading
--  or trailing blank lines shall not result in empty records at the beginning
--  or end of the input, and a _newline_ shall always be a field separator, no
--  matter what the value of @{FS} is.
M.RS = '\n'

--- The starting position of the string matched by the match function, numbering
--  from 1. This shall always be equivalent to the return value of the match
--  function.
M.RSTART = 0

local fileinfo = {}

--- Set `var` to the next input record from the current input file. If `var`
--  is unspecified, set record to @{0|$0}.
--
--  This form of getline should update the values of `NF`, `NR`, and `FNR`.
--
--  @param[type=string,opt] var  Set variable var to the next input
--   record from the current input file.
--
--  @return[type=boolean] Shall return true for successful input, false for
--   end-of-file and raise an error otherwise.
-- @function Runtime:getline
function M:getline(var)
    local filename = self.FILENAME
    local rs = self.RS and self.RS:sub(1,1) or ""
    local info = fileinfo[filename]
    if filename == "-" then
        filename = "/dev/stdin"
    end
    if info == nil then
        -- TODO check for file type
        local handle, msg = io.open(filename)
        if handle == nil then
            abort("getline: %s\n", msg)
        end
        info = {
            handle = handle,
            nr = 0
        }
        fileinfo[self.FILENAME] = info
    end
    -- TODO read record delimited by RS
    -- TODO The first character of the string value of RS shall be
    --      the input record separator; a <newline> by default.
    --      If RS contains more than one character, the results
    --      are unspecified.
    -- TODO If RS is null, then records are separated by sequences
    --      consisting of a <newline> plus one or more blank lines,
    --      leading or trailing blank lines shall not result in empty
    --      records at the beginning or end of the input, and a
    --      <newline> shall always be a field separator, no matter
    --      what the value of FS is.
    local rec
    if rs == "\n" then
        rec = info.handle:read()
    elseif rs == "" then
        abort("getline: empty RS not implemented\n")
    else
        abort("getline: non-standard RS not implemented\n")
    end
    if rec == nil then
        fileinfo[filename] = nil
        local s, msg = pcall(io.close, info.handle)
        if not s then
            error(msg, -1)
        end
        return false
    elseif var then
        self[var] = rec
    else
        self[0] = rec
    end
    info.nr = info.nr + 1
    self.FNR = info.nr
    self.NR = self.NR + 1
    return true
end

--- Print arguments to `io.stdout` delimited by `OFS` using `tostring`. If no arguments are
--  given, the record value @{0|$0} is printed.
--  @param ... the arguments
--  @function Runtime:print
function M:print(...)
    local ofs = tostring(self.OFS)
    local ors = tostring(self.ORS)
    if select('#', ...) > 0 then
        -- FIXME implementation far from optimal
        local args = {...}
        local stab = setmetatable({}, {
            __index = function(_,k) return args[k] and tostring(args[k]) or "" end,
            __len = function() return #args end
        })
        io.stdout:write(table.concat(stab, ofs), ors)
    else
        io.stdout:write(self[0], ors)
    end
end

--- Prints to `io.stdout` by passing the arguments to `string.format`.
--  @param ... the arguments
--  @function Runtime:printf
function M:printf(...)
    io.stdout:write(string.format(...))
end

--- Return the position, in characters, numbering from 1, in string `s` where
--  the extended regular expression `p` occurs, or zero if it does not occur
--  at all. @{RSTART} shall be set to the starting position
--  (which is the same as the returned value), zero if no match is found;
--  @{RLENGTH} shall be set to the length of the matched
--  string, -1 if no match is found.
--
--  @param[type=string] s  input string
--  @param[type=string] p  pattern
--  @return[type=number] position of first match, or nil
--
--  @see RSTART
--  @see RLENGTH
--  @see regex.find
--  @function Runtime:match
function M:match(...)
    local argc, s, p = select('#', ...), ...
    --- @TODO fix description
    if not self then
        abort("split: self expected, got: %s\n", type(self))
    end
    s = s and tostring(s) or ""
    p = p and tostring(p) or ""
    local rstart, rend = regex.find(s,p)
    if rstart then
        self.RSTART = rstart
        self.RLENGTH = rend - rstart + 1
        return rstart
    else
        self.RSTART = 0
        self.RLENGTH = -1
    end
    return nil
end

--- Split string `s` into array `a` by `fs` and return `n`.
--
--  All elements of the array shall be deleted before the split is performed.
--  The separation shall be done with the ERE fs or with the field separator
--  @{FS} if fs is not given. Each array element shall have a string value
--  when created and, if appropriate, the array element shall be considered
--  a numeric string (see Expressions in awk). The effect of a null string
--  as the value of fs is unspecified.
--
--  The _null string_ pattern (`""`) causes the characters of `s` to be
--  enumerated into `a`.
--
--  The _literal space_ pattern (`"\x20"`) matches any number of characters
--  of _space_ (space, tab and newline), leading and trailing spaces are
--  trimmed from input. Any other single character (e.g. `","`) is treated as
--  a _literal_ pattern.
--
--  Any other pattern is considered as regex pattern in the domain of lua.
--
--  @usage
--    local F = require "luawk.runtime.posix":new()
--    local n = F:split "a b c"
--    --    n = 3
--    -- F[1] = "a"
--    -- F[2] = "b"
--    -- F[3] = "c"
--
--  @param[type=string] s  input string
--  @param[type=table,opt=self] a  split into array
--  @param[type=string,opt=self.FS] fs  field separator
--  @return[type=number]  number of fields
--
--  @see FS
--  @see regex.find
--  @function Runtime:split
function M:split(...)
    -- TODO Seps is a gawk extension, with seps[i] being the separator string
    -- between array[i] and array[i+1]. If fieldsep is a single space, then any
    -- leading whitespace goes into seps[0] and any trailing whitespace goes
    -- into seps[n], where n is the return value of split() (i.e., the number of
    -- elements in array).
    -- TODO If RS is null, then records are separated by sequences consisting of
    -- a <newline> plus one or more blank lines, leading or trailing blank lines
    -- shall not result in empty records at the beginning or end of the input,
    -- and a <newline> shall always be a field separator, no matter what the
    -- value of FS is.
    local argc, s, a, fs = select('#', ...), ...
    if not self then
        abort("split: self expected, got: %s\n", type(self))
    end
    if argc == 0 then
        abort("split: first argument is mandatory\n")
    end
    if argc > 1 and not isarray(a) then
        abort("split: second argument is not an array\n")
    end
    s = s ~= nil and tostring(s) or ""
    a = a or self
    fs = fs ~= nil and tostring(fs) or (self.FS or '\32')
    -- special mode
    if fs == '\32' then
        s = trim(s)
        fs = '[\32\t\n]+'
    end
    -- clear array
    if a == self then
        self[0] = ""
    else
        for i in ipairs(a) do
            a[i] = nil
        end
    end
    if s == "" then
        -- nothing to do
        return 0
    end
    if fs == "" then
        -- special null string mode
        -- empty field separator, split to characters
        local i = 1
        for c in string.gmatch(s, utf8charpattern) do
            a[i] = c
            i = i + 1
        end
        return #a
    else
        -- standard regex mode
        local i, j = 1, 1
        local b, c = regex.find(s, fs, j)
        while b do
            a[i] = string.sub(s, j, b - 1)
            j = c + 1
            i = i + 1
            b, c = regex.find(s, fs, j)
        end
        a[i] = string.sub(s, j)
        return #a
    end
end

--- The record, usually set by `getline`.
--  @class field
--  @label virtual
--  @name 0
--  @see getline

--- Fields as handled by @{split}() for @{0|$0}.
--  @usage
--    local F = require 'luawk.runtime.posix':new()
--    F.OFS = ","
--    F[0] = "a b c"
--    F[NF+1] = "d"
--    -- F.NF = 4
--    -- F[0] = "a,b,c,d"
--  @class field
--  @label virtual
--  @name 1..NF
--  @see split
--  @see NF

local function splitR(R, self)
    R.nf = self.split(R[0], R, self.FS)
    log.trace("    [*]=%s <rebuilt>\n", R)
end

local function joinR(R, self)
    local ofs = tostring(self.OFS)
    -- build $0 from $1..$NF
    rawset(R, 0, table.concat(self, ofs, 1, R.nf))
    log.trace("    [0]=%s <rebuilt>\n", R[0])
end

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=Runtime]
--  @function new
local function new(obj)
    -- @TODO R should use weak references
    local R = {
        [0] = "",
        nf = 0,
        split = splitR,
        join = joinR,
    }
    obj = obj or {}
    local runtime = setmetatable({}, {
        record = R,
        __index = function(self,k)
            log.debug("get [%s]\n", k)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                if idx == 0 and R[0] == nil then
                    -- (re)build record from fields
                    R:join(self)
                end
                local val = nil
                if idx <= R.nf then
                    val = R[idx] or ""
                end
                log.trace("    [%s]=%s <record>\n", k, val)
                return val
            end
            if k == "NF" then
                log.trace("    [%s]=%s <record>\n", k, R.nf)
                return R.nf
            end
            local val = M[k]
            if type(val) == "function" then
                -- wrap function self
                local proxy = function(...)
                    return val(self, ...)
                end
                log.trace("    [%s]=%s <default> (%s)\n", k, proxy, val)
                rawset(self, k, proxy)
                return proxy
            end
            if val ~= nil then
                log.trace("    [%s]=%s <default>\n", k, val)
                rawset(self, k, val)
                return val
            end
            val = obj[k]
            if val ~= nil then
                log.trace("    [%s]=%s <global>\n", k, val)
                rawset(self, k, val)
                return val
            end
            log.trace("    [%s]=nil <not found>\n", k)
            return nil
        end,
        __newindex = function(self,k,v)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                log.debug("set [%s]=%s <field>\n", idx, v)
                v = v ~= nil and tostring(v) or ""
                if idx == 0 then
                    rawset(R, 0, v)
                    R:split(self)
                else
                    R.nf = math.max(idx, R.nf)
                    log.trace("    [%s]=%s <field>\n", idx, v)
                    rawset(R, idx, v)
                    -- (re)build record from fields
                    R:join(self)
                end
            elseif k == "NF" then
                log.debug("set [%s]=%s <virtual>\n", k, v)
                local nf = R.nf
                -- ensure NF is always a number
                R.nf = math.max(math.modf(tonumber(v) or 0), 0)
                if nf > R.nf then
                    -- clear fields after NF
                    for i=R.nf+1,nf do
                        log.trace("    [%s]=%s <field>\n", i, nil)
                        R[i] = nil
                    end
                end
                -- (re)build record from fields
                R:join(self)
            else
                log.debug("set [%s]=%s <runtime>\n", k, v)
                rawset(self, k, v)
            end
        end,
        __len = function()
            return R.nf
        end
    })
    if log.level == "trace" then
        return setmetatable({}, {
            __index = function(_,k)
                log.debug("get [%s]\n", k)
                local v = rawget(runtime, k)
                if v ~= nil then
                    log.trace("    [%s]=%s <cached>\n", k, v)
                    return v
                end
                return runtime[k]
            end,
            __newindex = function(_,k,v)
                log.debug("set [%s]=%s\n", k, v)
                runtime[k] = v
            end,
            __len = function()
                return #runtime
            end
        })
    end
    return runtime
end

return {
    new = new
}
