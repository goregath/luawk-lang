--- Lua 5.3 compatibility module.
-- @alias M
-- @module compat53

local version = tonumber((
    assert(
        _VERSION:sub(-3):match("5%.%d"),
        "unable to parse lua version"
    ):gsub("%D", "")
))
assert(
    version >= 51 and version < 60,
    "version mismatch, expected lua >= 5.1 and < 6.0"
)

local M = {
    load = load,
    utf8 = utf8
}

if version < 53 then
    M.utf8 = {
        charpattern =
            version == 51
            and "[%z\1-\127\194-\244][\128-\191]*"
            or  "[\0-\127\194-\244][\128-\191]*"
    }
end

if version == 51 then
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

return M