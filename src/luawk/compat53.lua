--- Lua 5.3 compatibility module.
-- @alias M
-- @module compat53

-- TODO Write wrapper for bitlib when targeting lua <5.3

-- EXCERPT FROM ERDE MANUAL
-- ========================

-- Compiling bitwise operators heavily depends on the Lua target. Erde uses
-- the following table to determine how bit operations should be compiled:

-- | Target | Compilation            | Erde  |               Lua              |
-- |--------|------------------------|-------|:------------------------------:|
-- | jit    | LuaBitOp               | 6 & 5 | require('bit').band(6, 5)      |
-- | 5.1    | LuaBitOp               | 6 & 5 | require('bit').band(6, 5)      |
-- | 5.1+   | Requires --bitlib flag | 6 & 5 | require('myBitLib').band(6, 5) |
-- | 5.2    | bit32                  | 6 & 5 | require('bit32').band(6, 5)    |
-- | 5.2+   | Requires --bitlib flag | 6 & 5 | require('myBitLib').band(6, 5) |
-- | 5.3    | Native Syntax          | 6 & 5 | 6 & 5                          |
-- | 5.3+   | Native Syntax          | 6 & 5 | 6 & 5                          |
-- | 5.4    | Native Syntax          | 6 & 5 | 6 & 5                          |
-- | 5.4+   | Native Syntax          | 6 & 5 | 6 & 5                          |

-- You may also specify your own bit library using the --bitlib flag in the
-- CLI. The library methods are assumed to be:

-- | Syntax | Operator    | Method                     |
-- |--------|-------------|----------------------------|
-- | \|     | or          | require('myBitLib').bor    |
-- | &      | and         | require('myBitLib').band   |
-- | ~      | xor         | require('myBitLib').bxor   |
-- | ~      | unary NOT   | require('myBitLib').bnot   |
-- | >>     | right shift | require('myBitLib').rshift |
-- | <<     | left shift  | require('myBitLib').lshift |

-- CAUTION:
-- -------

-- > Trying to compile bitwise operators when targeting 5.1+ or 5.2+ requires
-- > the use of --bitlib. This is because there really is no "sane" default
-- > here. By far the most common bit libraries for Lua are LuaBitOp
-- > (only works on 5.1 and 5.2) and bit32 (only works on 5.2), so it is left
-- > to the developer to decide which library to use.

local M = {
    load = load,
    utf8 = utf8
}

local major, minor = (_VERSION or ""):match("(%d)%.(%d)")

assert(major and minor, "unable to parse lua version")
major, minor = tonumber(major), tonumber(minor)

local version = major * 100 + minor
assert(
    version > 501,
    "lua version mismatch, expected lua 5.1 or newer"
)

if version < 503 then
    M.utf8 = {
        charpattern =
            version == 501
            and "[%z\1-\127\194-\244][\128-\191]*"
            or  "[\0-\127\194-\244][\128-\191]*"
    }
end

if version == 501 then
    local load = assert(load)
    local loadstring = assert(loadstring)
    local setfenv = assert(setfenv)
    function M.load(chunk, chunkname, _, env)
        local f, msg
        if type(chunk) == "string" then
            f, msg = loadstring(chunk, chunkname)
        else
            f, msg = load(chunk, chunkname)
        end
        if not f then
            return nil, msg
        end
        return env and setfenv(f, env) or f
    end
end

M.version = string.format("%d.%d", major, minor)
M.version_normalized = version
M.version_major = major
M.version_minor = minor

return M