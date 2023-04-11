--- GNU AWK Runtime Environment.
--
-- Extends the @{posix|posix (Runtime)} environment.
-- @runtime gnu
--
-- @usage require("luawk.runtime.gnu").new(_G)
-- @see gawk(1)

local posix = require 'luawk.runtime.posix'
local regex = require 'luawk.regex'
local utils = require 'luawk.utils'
local isarray = utils.isarray
local abort = utils.fail

--- The runtime class
local class = setmetatable({}, { __index = posix.class })

--- Constructors
-- @section

--- Create a new new instance of `gnu.class`.
--  @param[type=table,opt] lower a backing table
--  @return A new instance of `gnu.class`
local function new(lower)
    return class:new(lower)
end

--- Class Fields.
-- @section

--- On non-posix systems, this variable specifies use of binary mode for all I/O.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
class.BINMODE = ''

--- If a system error occurs during a redirection for getline, during a read
--  for getline, or during a close() operation, then ERRNO contains a string
--  describing the error.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
class.ERRNO = ''

--- A space-separated list of columns that tells gawk how to split input with
--  fixed columnar boundaries.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
class.FIELDWIDTHS = ''

--- If IGNORECASE is nonzero or non-null, then all string comparisons and all
--  regular expression matching are case-independent.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
class.IGNORECASE = ''

--- Ignored
class.LINT = ''

--- The elements of this array provide access to information about the running awk program.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
class.PROCINFO = ''

--- Used for internationalization of programs at the awk level.
class.TEXTDOMAIN = ''

--- Reserved Fields.
--  Variables reserved by an luawk-compliant runtime.
--  @section reserved_fields

--- The index in ARGV of the current file being processed.
--  https://www.gnu.org/software/gawk/manual/html_node/POSIX_002fGNU.html
--  @class field
--  @name obj.ARGIND
--  @default <code>nil</code> (unset)
--  @see patsplit
--  @see posix.FS

--- A regular expression (as a string) that is used to split text into fields
--  that match the regular expresson. Assigning a value to @{FPAT} overrides
--  the use of @{posix.FS} and @{FIELDWIDTHS} for field splitting.
--  @class field
--  @name obj.FPAT
--  @default <code>nil</code> (unset)
--  @see patsplit
--  @see posix.FS

--- The input text that matched the text denoted by RS, the record separator.
--  It is set every time a record is read.
--  @class field
--  @name obj.RT
--  @default <code>nil</code> (unset)
--  @see posix.getline

--- Methods
-- @section

--- Split the string `s` into fields of array `a` matching pattern `fp` and return `n`.
--
--  @usage
--      local libawk = require("luawk.runtime.gnu")
--      local gawk = libawk.new()
--      local a, s = {}, {}
--      local n = gawk:patsplit("0xDEAD, 0xBEEF", a, "%x%x", s)
--      -- n = 4
--      -- a = { "DE", "AD", "BE", "EF" }
--      -- s = { [0]="0x", "", ", 0x", "", "" }
--
--  @param[type=string] s  input string
--  @param[type=table,opt=self] a  split fields into array
--  @param[type=string,opt=self.FPAT] fp  field pattern
--  @param[type=table,opt] seps  save separators into array
--  @return[type=number] number of fields
--  @return[type=...] indices of fields in s
--
--  @see posix
--  @see FPAT
--  @depends regex.find
--  @function class:patsplit
function class:patsplit(...)
    local argc, s,a,fp,seps = select('#', ...), ...
    -- TODO RELEASE UNDER DIFFERENT LIBRARY AND LICENSE
    -- TODO THIS IS GNU General Public License v3.0
    -- https://github.com/gvlx/gawk/blob/a892293556960b0813098ede7da7a34774da7d3c/field.c#L1052
    -- https://github.com/gvlx/gawk/blob/a892293556960b0813098ede7da7a34774da7d3c/field.c#L1472
    s = s ~= nil and tostring(s) or ""
    a = a or self
    fp = fp ~= nil and tostring(fp) or self.FPAT
    if not self then
        abort("patsplit: self expected, got: %s", type(self))
    end
    if argc == 0 then
        abort("patsplit: first argument is mandatory")
    end
    if argc > 1 and not isarray(a) then
        abort("patsplit: second argument is not an array")
    end
    if fp == nil or fp == "" then
        abort("patsplit: third argument cannot be empty")
    end
    if seps ~= nil and not isarray(seps) then
        abort("patsplit: fourth argument is not an array")
    end
    if a == seps then
        abort("patsplit: second and fourth array cannot be the same")
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
    -- standard regex mode
    local found = {}
    local empty = true
    local i, b, c = 1, regex.find(s, fp, 1)
    while b do
        if c >= b then
            -- easy case
            empty = false
            a[i] = string.sub(s, b, c)
            found[i] = b
            if c >= #s then break end;
            c = c + 1
            i = i + 1
        elseif not empty then
            -- last match was non-empty, and at the
            -- current character we get a zero length match,
            -- which we don't want, so skip over it
            empty = true
            c = c + 2
        else
            a[i] = ""
            found[i] = b
            if b == 1 then
                c = c + 2
            else
                c = b + 1
            end
            i = i + 1
            empty = true
        end
        b, c = regex.find(s, fp, c)
    end
    if seps then
        for j in ipairs(seps) do
            a[j] = nil
        end
        -- extract separators from string
        local pp = 1
        for j,p in ipairs(found) do
            seps[j-1] = string.sub(s, pp, p-1)
            pp = p + #a[j]
        end
        seps[#found] = string.sub(s, found[#found] + #a[#found])
    end
    return #a, table.unpack(found)
end

--- @export
return {
    class = class,
    new = new,
}