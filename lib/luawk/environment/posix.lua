--- POSIX AWK Runtime Environment.
-- @usage
--     local libenvironment = require("luawk.environment.posix")
--     local environment = libenvironment.new(_G)
-- @environment posix
-- @see awk(1p)

local stdlib = require 'posix.stdlib'
local setenv = stdlib.setenv
local getenv = stdlib.getenv

local regex = require 'luawk.regex'
local utils = require 'luawk.utils'
local isarray = utils.isarray
local trim = utils.trim
local abort = utils.fail
local utf8 = require 'luawk.compat53'.utf8

--- The environment class
local class = {}

--- Constructors
-- @section

local function split(R, self)
    if R[0] == "" then
        R.n = 0
    else
        R.n = self.split(R[0], R, self.FS)
    end
end

local function join(R, self)
    if R.n == 0 then
        R[0] = ""
    else
        local ofs = tostring(self.OFS)
        -- build $0 from $1..$NF
        R[0] = table.concat(self, ofs, 1, R.n)
    end
end

local next

--- Create a new new instance of `posix.class`.
--  @param[type=table,opt] lower a backing table
--  @return A new instance of `posix.class`
local function new(lower)
    return class:new(lower)
end

--- Create a new new instance of `posix.class`.
--  @param[type=table,opt] lower a backing table
--  @return A new instance of `posix.class`
function class:new(lower)
    -- @TODO R should use weak references
    local R = { n = 0 }
    lower = lower or {}
    local upper = setmetatable({}, {
        __index = function(t,k)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                local val = nil
                if idx <= R.n then
                    val = R[idx] or ""
                end
                return val
            end
            if k == "NF" then
                return R.n
            end
            local val = self[k]
            if type(val) == "function" then
                -- wrap function t
                local proxy = function(...)
                    return val(t, ...)
                end
                rawset(t, k, proxy)
                return proxy
            end
            if val ~= nil then
                rawset(t, k, val)
                return val
            end
            val = lower[k]
            if val ~= nil then
                rawset(t, k, val)
                return val
            end
            return nil
        end,
        __newindex = function(t,k,v)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                v = v ~= nil and tostring(v) or ""
                if idx == 0 then
                    R[0] = v
                    split(R, t)
                else
                    R.n = math.max(idx, R.n)
                    R[idx] = v
                    -- (re)build record from fields
                    join(R, t)
                end
            elseif k == "NF" then
                local n = R.n
                -- ensure NF is always a number
                R.n = math.max(math.modf(tonumber(v) or 0), 0)
                if n > R.n then
                    -- clear fields after NF
                    for i=R.n+1,n do
                        R[i] = nil
                    end
                end
                -- (re)build record from fields
                join(R, t)
            else
                rawset(t, k, v)
            end
        end,
        __add = function(t,l)
            if type(l) == "table" or type(l) == "userdata" then
                for _,v in ipairs(t == l and { table.unpack(l) } or l) do
                    table.insert(t,v)
                end
            else
                table.insert(t,l)
            end
            return t
        end,
        __len = function()
            return R.n
        end
    })
    return upper
end

--- Class Fields.
-- @section

--- The number of elements in the @{ARGV} array.
--  @default <code>0</code>
class.ARGC = 0

--- An array of command line arguments, excluding options and the program
--  argument, numbered from zero to @{ARGC}-1. The arguments in @{ARGV} can be
--  modified or added to; @{ARGC} can be altered. As each input file ends, awk
--  shall treat the next non-null element of @{ARGV}, up to the current value of
--  @{ARGC}-1, inclusive, as the name of the next input file. Thus, setting an
--  element of @{ARGV} to null means that it shall not be treated as an input
--  file. The name `'-'` indicates the standard input. If an argument matches the
--  format of an assignment operand, this argument shall be treated as an
--  assignment rather than a file argument.
--  @default `{}`
class.ARGV = {}

--- The printf format for converting numbers to strings (except for output
--  statements, where @{OFMT} is used); `"%.6g"` by default.
--  @default `"%.6g"`
class.CONVFMT = "%.6g"

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
--  @table class.ENVIRON
--  @see getenv(3)
--  @see setenv(3)
class.ENVIRON = setmetatable({}, {
    __index = function(_, k) return os.getenv(k) end,
    __newindex = function(_,k,v) setenv(k,v) end,
    __pairs = function() return pairs(getenv()) end,
})

--- The ordinal number of the current record in the current file. Inside a _BEGIN_
--  action the value shall be zero. Inside an _END_ action the value shall be the
--  number of the last record processed in the last file processed.
--  @default <code>0</code>
class.FNR = 0

--- Input field separator regular expression; a _space_ by default.
--  @see split
--  @default `"\32"` (blank)
class.FS = '\32'

--- The ordinal number of the current record from the start of input. Inside a
--  _BEGIN_ action the value shall be zero. Inside an _END_ action the value shall
--  be the number of the last record processed.
--  @default <code>0</code>
class.NR = 0

--- The printf format for converting numbers to strings in output statements
--  (see Output Statements); `"%.6g"` by default. The result of the conversion is
--  unspecified if the value of @{OFMT} is not a floating-point format
--  specification.
--  @default `"%.6g"`
class.OFMT = "%.6g"

--- The print statement output field separator; _space_ by default.
--  @default `"\32"` (blank)
class.OFS = '\32'

--- The print statement output record separator; a _newline_ by default.
--  @default `"\n"` (newline)
class.ORS = '\n'

--- The length of the string matched by the match function.
--  @default <code>0</code>
class.RLENGTH = 0

--- The record separator string, its value is interpreted by @{getlines}.
--  @default `"\n"` (newline)
--  @see getlines
class.RS = '\n'

--- The starting position of the string matched by the match function, numbering
--  from 1. This shall always be equivalent to the return value of the match
--  function.
--  @default <code>0</code>
class.RSTART = 0

--- Reserved Fields.
--  Variables reserved by an luawk-compliant environment.
--  @section reserved_fields

--- A pathname of the current input file. Inside a _BEGIN_ action the value is
--  undefined. Inside an _END_ action the value shall be the name of the last
--  input file processed.
--  @class field
--  @name obj.FILENAME
--  @default <code>nil</code> (unset)

--- Methods
-- @section

--- Close the file or pipe opened by a `print` or `printf` statement or a call to
--  `getline` with the same string-valued expression.
--
--  @param[type=string] fd  A string representation of the file or pipe.
--
--  @return[1,type=true] On success
--  @return[2,type=nil]
--  @return[2,type=string] Message describing the error
--
--  @class function
--  @name class:close
function class:close(fd)
    -- TODO implement fd cache
    abort("close: not implemented")
end

--- Return a new iterator function of @{next} with the opened file handle.
--
--  @usage
--    local F = require "luawk.environment.posix".new()
--    F.RS = "\n"
--    for record, rt in F.getlines("-") do
--      print(record)
--    end
--
--  @param file A filename or opened handle
--
--  @return[1,type=next] iterator
--  @return[1,type=table] state
--  @return[1,type=nil] var
--  @return[2,type=nil] In case `file` is not a valid file handle and could not be opened for reading
--  @return[2,type=string] Message describing the error
--
--  @class function
--  @name class:getlines
function class:getlines(...)
    local pagesize = 256
    local argc, obj = select('#', ...), ...
    if not self then
        abort("getlines: self expected, got: %s", type(self))
    end
    if argc == 0 then
        abort("getlines: first argument is mandatory")
    end
    local objtype = type(obj)
    local state = { "" }
    if objtype == "string" then
        local handle, msg = io.open(obj:gsub("^-$", "/dev/stdin"), "r")
        if not handle then
            return nil, msg
        end
        local fileno = require "posix.stdio".fileno
        local isatty = require "posix.unistd".isatty
        if isatty(fileno(handle)) then
            pagesize = 1
            handle:setvbuf("no")
        else
            handle:setvbuf("full", pagesize)
        end
        state.read = function(sz)
            return handle:read(sz or pagesize)
        end
    elseif objtype == "table" or objtype == "userdata" and type(obj.read) == "function" then
        state.read = function(sz)
            return obj:read(sz or pagesize)
        end
    elseif objtype == "function" then
        state.read = obj
    elseif objtype == "thread" then
        state.read = function(sz)
            if coroutine.status(obj) == "dead" then
                return nil
            end
            return select(2, coroutine.resume(obj, sz or pagesize))
        end
    else
        return nil, string.format("getlines: invalid type: %s", objtype)
    end
    return next, setmetatable(state, { __index = self }), nil
end

--- Print arguments to `io.stdout` delimited by `ORS` using `tostring`. If no arguments are
--  given, the record value @{0|$0} is printed.
--
--  @usage
--    local F = require "luawk.environment.posix".new()
--    F[0] = "a b c"
--    F.print()
--    -- a b c
--    F.OFS = ","
--    F.print(1, nil, true)
--    -- 1,,true
--
--  @see ORS
--  @param ... the arguments
--  @class function
--  @name class:print
function class:print(...)
    local ofs = tostring(self.OFS)
    local ors = tostring(self.ORS)
    local n = select('#', ...)
    if n > 0 then
        local sep, args = "", { ... }
        for i = 1, n do
            local arg = args[i]
            print("log", string.format("%q", type(arg)))
            io.stdout:write(sep, arg == nil and "" or tostring(arg))
            sep = ofs
        end
        io.stdout:write(ors)
    else
        io.stdout:write(self[0], ors)
    end
end

--- Prints to `io.stdout` by passing the arguments to `string.format`.
--  @param ... the arguments
--  @class function
--  @name class:printf
function class:printf(...)
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
--  @depends regex.find
--  @class function
--  @name class:match
function class:match(...)
    local argc, s, p = select('#', ...), ...
    -- TODO fix description
    if not self then
        abort("match: self expected, got: %s", type(self))
    end
    if argc < 2 then
        abort("match: invalid number of arguments")
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
--    local F = require "luawk.environment.posix".new()
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
--  @depends regex.find
--  @class function
--  @name class:split
function class:split(...)
    -- TODO Seps is a gawk extension, with seps[i] being the separator string
    -- between array[i] and array[i+1]. If fieldsep is a single space, then any
    -- leading whitespace goes into seps[0] and any trailing whitespace goes
    -- into seps[n], where n is the return value of split() (i.e., the number of
    -- elements in array).
    -- TODO WRITE TEST: If RS is null, then records are separated by sequences consisting of
    -- a <newline> plus one or more blank lines, leading or trailing blank lines
    -- shall not result in empty records at the beginning or end of the input,
    -- and a <newline> shall always be a field separator, no matter what the
    -- value of FS is.
    -- TODO WRITE TEST: When RS is set to the empty string and FS is set to a single
    -- character, the newline character always acts as a field separator. This
    -- is in addition to whatever field separations result from FS.
    local argc, s, a, fs = select('#', ...), ...
    local rsmode = self.RS == nil or tostring(self.RS) == ""
    if not self then
        abort("split: self expected, got: %s", type(self))
    end
    if argc == 0 then
        abort("split: first argument is mandatory")
    end
    if argc > 1 and not isarray(a) then
        abort("split: second argument is not an array")
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
        for c in string.gmatch(s, utf8.charpattern) do
            a[i] = c
            i = i + 1
        end
        return #a
    else
        -- GAWK: If RS is null, […] a <newline> shall always be a field
        -- separator, no matter what the value of FS is.
        local find = not rsmode and regex.find or function(c, p, i)
            local m, n = regex.find(c, p, i)
            local x, y = string.find(c, '\n', i, true)
            if not m or x and x < m then
                return x, y
            end
            return m, n
        end
        -- pattern mode
        local i, j = 1, 1
        local b, c = find(s, fs, j)
        while b do
            a[i] = string.sub(s, j, b - 1)
            j = c + 1
            i = i + 1
            b, c = find(s, fs, j)
        end
        a[i] = string.sub(s, j)
        return #a
    end
end

--- Reserved Methods.
--  Methods reserved by an luawk-compliant environment.
--  @section reserved_methods

--- Skip current record.
--  @class function
--  @name class:next

--- Skip current file.
--  @class function
--  @name class:nextfile

--- Cancel main loop and jump to END action.
--  @class function
--  @name class:exit

--- Object Fields.
--  @section

--- The record, usually set by `getlines`.
--  @class field
--  @name 0
--  @fieldof obj
--  @see getlines
--  @default `""` (_nullstring_)

--- Fields as handled by @{split}() for @{0|$0}.
--  @usage
--    local F = require 'luawk.environment.posix':new()
--    F.OFS = ","
--    F[0] = "a b c"
--    F[NF+1] = "d"
--    -- F.NF = 4
--    -- F[0] = "a,b,c,d"
--  @class field
--  @name 1..NF
--  @fieldof obj
--  @see split
--  @see NF
--  @default `nil` (when index not `[1,NF]`, `string` otherwise)

--- The number of fields in the current record. Inside a _BEGIN_ action, the use
--  of @{NF} is undefined unless a getline function without a var argument is
--  executed previously. Inside an _END_ action, @{NF} shall retain the value it had
--  for the last record read, unless a subsequent, redirected, getline function
--  without a var argument is performed prior to entering the _END_ action.
--  @class field
--  @name obj.NF
--  @default <code>0</code> (when @{0|obj[0]} is the nullstring)

--- Iterators
-- @section

--- A stateful iterator function returned by @{getlines}.
--
--  This functions splits the contents of a file (`state.handle`) based
--  on the value of the record seperator variable @{RS|state.RS}.
--
--  If @{RS} contains more than one character, its value is interpreted as a
--  pattern under the domain of @{regex.find}.
--
--  If @{RS} is null, then records are separated by sequences consisting of a
--  _newline_ plus one or more blank lines, leading or trailing blank lines shall
--  not result in empty records at the beginning or end of the input, and a
--  _newline_ shall always be a field separator, no matter what the value of
--  @{FS} is.
--
--  @param[type=table] state The iterator state
--  @param ctrl The control variable (not used)
--
--  @return[1,type=string] Record string (match until @{RS})
--  @return[1,type=string] Record terminator (match of @{RS})
--  @return[2,type=fail] If an error occured or end of file has been reached
--
--  @class function
--  @name next
--  @see RS
--  @see getlines
--  @see regex.find
function next(state)
    -- TODO lua -lP=luawk.environment.posix -e'p=P.new() p.RS="\n\n+" for l,r in p.getlines("-") do print(l) end' <<<$'\n\na\n\nb\n'
    --      CORRECT => 0a 61 0a 62 0a |.a.b.|
    -- TODO awk -vRS="\n\n+" 1 <<<$'\n\na\n\nb\n'
    --      CORRECT => 0a 61 0a 62 0a |.a.b.|
    -- TODO ./luawk.lua -vRS=$'\n\n+' 1 <<<$'\n\na\n\nb\n'
    --      CORRECT => 0a 61 0a 62 0a |.a.b.|
    -- TODO ./luawk.lua -vRS="\n\n+" 1 <<<$'\n\na\n\nb\n'
    --      WRONG => 0a 0a 61 0a 0a 62 0a 0a  0a |..a..b...|
    if state.eof then
        return nil
    end
    local rs = state.RS and tostring(state.RS) or ""
    -- TODO AWK: If RS is null, then records are separated by sequences
    -- consisting of a <newline> plus one or more blank lines, leading
    -- or trailing blank lines shall not result in empty records at the
    -- beginning or end of the input, and a <newline> shall always be a
    -- field separator, no matter what the value of FS is.
    -- TODO GAWK: The empty string "" (a string without any characters)
    -- has a special meaning as the value of RS. It means that records
    -- are separated by one or more blank lines and nothing else. See
    -- Multiple-Line Records for more details.
    local find, plain, strip = string.find, true, false
    if rs == "" then
        -- GAWK: However, there is an important difference between ‘RS = ""’ and
        -- ‘RS = "\n\n+"’. In the first case, leading newlines in the input
        -- data file are ignored, and if a file ends without extra blank
        -- lines after the last record, the final newline is removed from
        -- the record. In the second case, this special processing is not
        -- done.
        find, rs, plain, strip = string.find, "\n\n+", false, true
    elseif rs:len() > 1 then
        -- GAWK: If you set RS to a regular expression that allows optional
        -- trailing text, such as ‘RS = "abc(XYZ)?"’, it is possible, due to
        -- implementation constraints, that gawk may match the leading part
        -- of the regular expression, but not the trailing part, particularly
        -- if the input text that could match the trailing part is fairly
        -- long. gawk attempts to avoid this problem, but currently, there’s
        -- no guarantee that this will never happen.
        find, plain = regex.find, nil
    end
    local found, i, j
    repeat
        if strip then
            state[1] = string.match(state[1], "\n*(.*)")
        end
        i,j = find(state[1], rs, 1, plain)
        found = i and (plain or j < state[1]:len())
        if not found and not state.eof then
            local dat = state.read()
            if dat then
                state[1] = state[1] .. dat
            else
                state.eof, i, j = true, find(state[1], rs, 1, plain)
                found = i
            end
        end
    until state.eof or found
    local rc, rt
    if found then
        rc, rt = string.sub(state[1],1,i-1), string.sub(state[1],i,j)
        state[1] = string.sub(state[1],j+1)
    elseif state.eof and state[1] ~= "" then
        if strip then
            rc, rt = string.match(state[1], "(.*[^\n])(\n*)$")
        else
            rc, rt = state[1], ""
        end
        state[1] = nil
    end
    return rc, rt
end

--- @export
return {
    class = class,
    new = new,
}
