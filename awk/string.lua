--- AWK string functions.
-- @alias M
-- @module string

-- luacheck: globals FS RSTART RLENGTH

--[[
The string functions in the following list shall be supported.
Although the grammar (see Grammar ) permits built-in functions
to appear with no arguments or parentheses, unless the argument
or parentheses are indicated as optional in the following list
(by displaying them within the "[]" brackets), such use is undefined.

    gsub(ere, repl[, in])
    index(s, t)
    length[([s])]
    match(s, ere)
    split(s, a[, fs  ])
    sprintf(fmt, expr, expr, ...)
    sub(ere, repl[, in  ])
    substr(s, m[, n  ])
    tolower(s)
    toupper(s)

All of the preceding functions that take ERE as a parameter expect
a pattern or a string valued expression that is a regular
expression as defined in Regular Expressions.
]]--

local lua_version = _VERSION:sub(-3)

local utf8_charpattern
if lua_version == "5.1" then
    utf8_charpattern = "[%z\1-\127\194-\244][\128-\191]*"
elseif lua_version == "5.2" then
    utf8_charpattern = "[\0-\127\194-\244][\128-\191]*"
else
    utf8_charpattern = utf8.charpattern
end

local M = {}

local function trim(s)
    local _, i = string.find(s, '^[\32\t\n]*')
    local j = string.find(s, '[\32\t\n]*$')
    return string.sub(s, i + 1, j - 1)
end

--- Return the position, in characters, numbering from 1, in string `s` where
--  the extended regular expression `p` occurs, or zero if it does not occur
--  at all. @{env.RSTART|RSTART} shall be set to the starting position
--  (which is the same as the returned value), zero if no match is found;
--  @{env.RLENGTH|RLENGTH} shall be set to the length of the matched
--  string, -1 if no match is found.
--  @param[type=string]  s input string
--  @param[type=string]  p pattern
--  @return[type=number]   position of first match, or zero
function M.match(s, p)
    -- TODO adjust docs
    -- FIXME which environment should be used?
    s = s and tostring(s) or ""
    p = p and tostring(p) or ""
    local rstart, rend = string.find(s,p)
    if rstart then
        RSTART = rstart
        RLENGTH = rend - rstart + 1
        return rstart
    end
    return nil
end

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--
--  All elements of the array shall be deleted before the split is performed.
--  The separation shall be done with the ERE fs or with the field separator
--  @{env.FS|FS} if fs is not given. Each array element shall have a string value
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
--  @param[type=string]        s  input string
--  @param[type=table]         a  split into array
--  @param[type=string,opt=FS] fs field separator
--  @return[type=number]          number of fields
function M.split(s, a, fs)
    -- TODO If RS is null, then records are separated by sequences
    --      consisting of a <newline> plus one or more blank lines,
    --      leading or trailing blank lines shall not result in empty
    --      records at the beginning or end of the input, and a
    --      <newline> shall always be a field separator, no matter
    --      what the value of FS is.
    assert(type(a) == "table", "split: second argument is not an array")
    s = s ~= nil and tostring(s) or ""
    fs = fs ~= nil and tostring(fs) or (FS or '\32')
    -- special mode
    if fs == '\32' then
        s = trim(s)
        fs = '[\32\t\n]+'
    end
    -- clear array
    for i in ipairs(a) do
        a[i] = nil
    end
    if fs == "" then
        -- special null string mode
        -- empty field separator, split to characters
        local i = 1
        for c in string.gmatch(s, utf8_charpattern) do
            rawset(a, i, c)
            i = i + 1
        end
        return #a
    else
        -- standard regex mode
        local i, j = 1, 1
        local b, c = string.find(s, fs, j)
        while b do
            rawset(a, i, string.sub(s, j, b - 1))
            j = c + 1
            i = i + 1
            b, c = string.find(s, fs, j)
        end
        rawset(a, i, string.sub(s, j))
        return #a
    end
end

--- Format the expressions according to the @{printf} format given by fmt and
--  return the resulting string.
--  @param[type=string]     fmt format string
--  @param[type=string,opt] ... arguments
--  @return[type=string]
function M.sprintf(fmt, ...)
    error("sprintf: not implemented", -1)
end

return M