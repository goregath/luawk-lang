--- GNU AWK runtime.
-- Dependencies: `POSIX`
-- @alias M
-- @classmod GNU
-- @usage local libawk = require("luawk.runtime.gnu")
-- @license GPLv3
-- @see POSIX
-- @see awk(1p)
-- @see gawk(1)

local M = {}

local array_type = { table = true, userdata = true }

--- A regular expression (as a string) that is used to split text into fields
--  that match the regular expresson. Assigning a value to @{FPAT} overrides
--  the use of @{POSIX.FS} and @{FIELDWIDTHS} for field splitting.
--  @see patsplit
--  @see POSIX.FS
M.FPAT = ''

--- Split the string s into array elements a[1], a[2], ..., a[n], and return n.
--  @usage
--      local libawk = require("luawk.runtime.gnu")
--      local gawk = libawk:new()
--      local a, s = {}, {}
--      local n = gawk:patsplit("0xDEAD, 0xBEEF", a, "%x%x", s)
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
--
--  @see POSIX.split
--  @see FPAT
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

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=GNU]
function M:new(obj)
	local libawk = require 'luawk.runtime.posix'
    obj = obj or {}
    setmetatable(obj, {
        __index = libawk:new(self)
    })
    return obj
end

return M