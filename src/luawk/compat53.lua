--- Lua 5.3 compatibility module.
-- @alias M
-- @module compat53

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

M.version_normalized = version
M.version_major = major
M.version_minor = minor

return M