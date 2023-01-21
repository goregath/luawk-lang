--- AWK string functions.
-- @alias export
-- @module string

local var = require "awk.variable"
local export = {}

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--
--  All elements of the array shall be deleted before the split is performed.
--  The separation shall be done with the ERE fs or with the field separator FS
--  if fs is not given. Each array element shall have a string value when
--  created and, if appropriate, the array element shall be considered a
--  numeric string (see Expressions in awk). The effect of a null string as the
--  value of fs is unspecified.
--
--  This implementation defines the null string to split string to characters.
--
--  * `nil`, `""`: (_empty_) split into characters
--  * `" "`:   (_space_) matches any number of characters of class whitespace
--  * `","`:   (_literal_) matches literal
--  * `",+"`:  (_pattern_) matches lua pattern
--
--  @tparam string s  input string
--  @tparam table  a  split into array
--  @tparam string fs (optional) field separator
--  @treturn number number of fields
function export.split(s, a, fs)
    s = s and tostring(s) or ""
    if fs == '\x20' then fs = "%s+"
    else fs = fs and tostring(fs) or var.FS end
    assert(type(a) == "table", "split: second argument is not an array")
    -- clear array
    for i in ipairs(a) do
        a[i] = nil
    end
    if fs == "" then
        -- empty field separator, split to characters
        local i = 1
        for c in string.gmatch(s, utf8.charpattern) do
            rawset(a, i, c)
            i = i + 1
        end
        return #a
    else
        -- pattern
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