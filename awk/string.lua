--- AWK string functions.
-- @alias export
-- @module string

-- luacheck: globals FS

-- TODO print
--      match
--      printf
--      sprintf

local export = {}

local function trim(s)
    local _, i = string.find(s, '^[\x20\t\n]*')
    local j = string.find(s, '[\x20\t\n]*$')
    return string.sub(s, i + 1, j - 1)
end

--- Format the expressions according to the printf format given by fmt and
--  return the resulting string.
--  @param fmt
function export.sprintf(fmt, ...)
    error("not implemented")
end

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--
--  All elements of the array shall be deleted before the split is performed.
--  The separation shall be done with the ERE fs or with the field separator
--  FS if fs is not given. Each array element shall have a string value when
--  created and, if appropriate, the array element shall be considered a
--  numeric string (see Expressions in awk). The effect of a null string as
--  the value of fs is unspecified.
--
--  The _null string_ pattern (`""`, `nil`) causes the characters of `s` to be
--  enumerated into `a`.
--
--  The _literal space_ pattern (`" "`) matches any number of characters
--  of _space_(space, tab and newline), leading and trailing spaces are
--  trimmed from input. Any other single character (e.g. `","`) is treated as
--  a _literal_ pattern.
--
--  Any other pattern is considered as regex pattern in the domain of lua.
--
--  @tparam         string s  input string
--  @tparam         table  a  split into array
--  @tparam[opt=FS] string fs field separator
--  @treturn number number of fields
function export.split(s, a, fs)
    assert(type(a) == "table", "split: second argument is not an array")
    s = s ~= nil and tostring(s) or ""
    fs = fs ~= nil and tostring(fs) or (FS or '\x20')
    -- special mode
    if fs == '\x20' then
        s = trim(s)
        fs = '[\x20\t\n]+'
    end
    -- clear array
    for i in ipairs(a) do
        a[i] = nil
    end
    if fs == "" then
        -- special null string mode
        -- empty field separator, split to characters
        local i = 1
        for c in string.gmatch(s, utf8.charpattern) do
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

return export