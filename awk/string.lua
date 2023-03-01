--- AWK string functions.
-- @alias M
-- @module string

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

GAWK extensions:

    patsplit(s, a [, r [, seps] ])
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

local array_type = { table = true, userdata = true }

local M = {
    find = string.find
}

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
--
--  @param[type=string] s  input string
--  @param[type=string] p  pattern
--  @return[type=number] position of first match, or zero
function M:match(s, p)
    -- TODO adjust docs
    -- FIXME which environment should be used?
    s = s and tostring(s) or ""
    p = p and tostring(p) or ""
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
function M:split(s, a, fs)
    -- TODO Seps is a gawk extension, with seps[i] being the separator string
    -- between array[i] and array[i+1]. If fieldsep is a single space, then any
    -- leading whitespace goes into seps[0] and any trailing whitespace goes
    -- into seps[n], where n is the return value of split() (i.e., the number of
    -- elements in array).
    --
    -- TODO If RS is null, then records are separated by sequences consisting of
    -- a <newline> plus one or more blank lines, leading or trailing blank lines
    -- shall not result in empty records at the beginning or end of the input,
    -- and a <newline> shall always be a field separator, no matter what the
    -- value of FS is.
    s = s ~= nil and tostring(s) or ""
    fs = fs ~= nil and tostring(fs) or (self.FS or '\32')
    if not array_type[type(a)] then
        error("split: second argument is not an array", -1)
    end
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

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--  @usage
--      local String = require("luawk.string")
--      local utils = String:new()
--      local a, s = {}, {}
--      local n = utils:patsplit("0xDEAD, 0xBEEF", a, "%x%x", s)
--      -- n = 4
--      -- a = { "DE", "AD", "BE", "EF" }
--      -- s = { [0]="0x", "", ", 0x", "", "" }
--
--  @param[type=string] s  input string
--  @param[type=table] a  split fields into array
--  @param[type=string,opt=FPAT] fp  field pattern
--  @param[type=table,opt] seps  save separators into array
--  @return[type=number] number of fields
--  @return[type=...] indices of fields in s
function M:patsplit(s,a,fp,seps)
    -- TODO RELEASE UNDER DIFFERENT LIBRARY AND LICENSE
    -- TODO THIS IS GNU General Public License v3.0
    -- https://github.com/gvlx/gawk/blob/a892293556960b0813098ede7da7a34774da7d3c/field.c#L1052
    -- https://github.com/gvlx/gawk/blob/a892293556960b0813098ede7da7a34774da7d3c/field.c#L1472
    s = s ~= nil and tostring(s) or ""
    fp = fp ~= nil and tostring(fp) or self.FPAT
    if not array_type[type(a)] then
        error("patsplit: second argument is not an array", -1)
    end
    if fp == nil or fp == "" then
        error("patsplit: third argument cannot be empty", -1)
    end
    if seps ~= nil and not array_type[type(seps)] then
        error("patsplit: fourth argument is not an array", -1)
    end
    if a == seps then
        error("patsplit: second and fourth array cannot be the same", -1)
    end
    -- clear array
    for i in ipairs(a) do
        a[i] = nil
    end
    if s == "" then
        -- nothing to do
        return 0
    end
    -- standard regex mode
    local found = {}
    local empty = true
    local b, c = self.find(s, fp, 1)
    while b do
        if c >= b then
            -- easy case
            empty = false
            table.insert(a, string.sub(s, b, c))
            table.insert(found, b)
            if c >= #s then break end;
            c = c + 1
        elseif not empty then
            -- last match was non-empty, and at the
            -- current character we get a zero length match,
            -- which we don't want, so skip over it
            empty = true
            c = c + 2
        else
            table.insert(a, "")
            table.insert(found, b)
            if b == 1 then
                c = c + 2
            else
                c = b + 1
            end
            empty = true
        end
        b, c = self.find(s, fp, c)
    end
    if seps then
        for i in ipairs(seps) do
            a[i] = nil
        end
        -- extract separators from string
        local pp = 1
        for i,p in ipairs(found) do
            seps[i-1] = string.sub(s, pp, p-1)
            pp = p + #a[i]
        end
        seps[#found] = string.sub(s, found[#found] + #a[#found])
    end
    return #a, table.unpack(found)
end

--- Format the expressions according to the @{printf} format given by fmt and
--  return the resulting string.
--  @param[type=string]     fmt format string
--  @param[type=string,opt] ... arguments
--  @return[type=string]
function M:sprintf(fmt, ...)
    error("sprintf: not implemented", -1)
end

function M:new(obj)
    obj = obj or {}
    setmetatable(obj, {
        __index = self
    })
    return obj
end

return M