--- POSIX AWK Runtime.
-- @usage local libawk = require("luawk.runtime.posix")
-- @runtime POSIX
-- @license MIT
-- @see awk(1p)

local stdlib = require 'posix.stdlib'
local setenv = stdlib.setenv
local getenv = stdlib.getenv

local utils = require 'luawk.utils'
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
--  @function Runtime:match
function M:match(...)
    local argc, s, p = select('#', ...), ...
    --- @TODO fix description
    if not self then
        abort("split: self expected, got: %s\n", type(self))
    end
    s = s and tostring(s) or ""
    p = p and tostring(p) or ""
    --- @TODO self.find not part of awk and could be from an external library
    local rstart, rend = self.find(s,p)
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

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--
--  All elements of the array shall be deleted before the split is performed.
--  The separation shall be done with the ERE fs or with the field separator
--  @{FS} if fs is not given. Each array element shall have a string value
--  when created and, if appropriate, the array element shall be considered
--  a numeric string (see Expressions in awk). The effect of a null string
--  as the value of fs is unspecified.
--
--  The _null string_ pattern (`""`, `nil`) causes the characters of `s` to be
--  enumerated into `a`.
--
--  The _literal space_ pattern (`" "`) matches any number of characters
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
    for i in ipairs(a) do
        a[i] = nil
    end
    if s == "" then
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
        local b, c = self.find(s, fs, j)
        while b do
            a[i] = string.sub(s, j, b - 1)
            j = c + 1
            i = i + 1
            b, c = self.find(s, fs, j)
        end
        a[i] = string.sub(s, j)
        return #a
    end
end

--- The record.
--  @class field
--  @label virtual
--  @name 0

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

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=Runtime]
--  @function new
local function new(obj)
    -- @TODO R should use weak references
    local R = { nf = 0 }
    obj = obj or {}
    setmetatable(obj, {
        __index = function(self,k)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                if idx == 0 and R[0] == nil then
                    -- build $0 from $1..$NF
                    rawset(R, 0, table.concat(self, self.OFS, 1, R.nf))
                end
                if idx > R.nf then return nil end
                return R[idx] or ""
            end
            if k == "NF" then
                return R.nf
            end
            local fn = M[k]
            if type(fn) == "function" then
                -- wrap function self
                local proxy = function(...)
                    return fn(self, ...)
                end
                rawset(self, k, proxy)
                return proxy
            end
            return M[k]
        end,
        __newindex = function(self,k,v)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                v = v and tostring(v) or ""
                if idx == 0 then
                    R.nf = self.split(v, R, self.FS)
                    rawset(R, 0, v)
                else
                    R.nf = math.max(idx, R.nf)
                    rawset(R, idx, v)
                    rawset(R, 0, nil)
                end
            elseif k == "NF" then
                -- ensure NF is always a number
                R.nf = math.modf(tonumber(v) or 0)
                rawset(R, 0, nil)
            else
                rawset(self, k, v)
            end
        end,
        __len = function()
            return R.nf
        end
    })
    return obj
end

return {
    new = new
}
