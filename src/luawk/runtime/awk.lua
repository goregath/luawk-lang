--- AWK runtime.
-- @alias M
-- @classmod awk
-- @license MIT

local M = {}

local array_type = { table = true, userdata = true }

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

--- Create a new object.
--  @param[type=table,opt] obj
function M:new(obj)
    obj = obj or {}
    setmetatable(obj, {
        __index = self
    })
    return obj
end

return M