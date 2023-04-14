--- Luawk utility functions.
-- @alias M
-- @module utils

local log = require 'luawk.log'

local M = {}

--  @param ... arguments for `string.format`
function M.abort(...)
    io.stderr:write(string.format(...))
    -- log.error(...)
    os.exit(1)
end

--- Call function and return its result or abort the callee raises an error.
--  @param fn  function
--  @param ... arguments
function M.acall(fn, ...)
    local cap = { pcall(fn, ...) }
    if cap[1] then
        return select(1, table.unpack(cap))
    end
    M.abort("error: %s\n", cap[2])
end

--- Pass arguments to `error` using `string.format`.
--  @param ... arguments for `string.format`
function M.fail(...)
    error(string.format(...), -1)
end

--- Check if argument is indexable.
--  @param a test subject
function M.isarray(a)
    local type = type(a)
    if type == "table" then return true end
    local mt = getmetatable(a)
    return mt and mt.__len and mt.__index and true
end

--- Iterates over arguments and returns the first module it could find.
--  @param ... modnames (see `require`)
function M.requireany(...)
    local pkgname
    for _,v in ipairs{...} do
        log.debug("require %s\n", v)
        pkgname = v
        local loaded, lib, where = pcall(require, pkgname)
        if loaded then
            log.debug("found %s at %s\n", v, where or package.searchpath(pkgname, package.path))
            return lib
        end
    end
end

--- Trim leading and trailing whitespace from `s` and return the resulting
--  substring.
--  @param[type=string] s input string
--  @return[type=string] trimmed string
function M.trim(s)
    local _, i = string.find(s, '^[\32\t\n]*')
    local j = string.find(s, '[\32\t\n]*$')
    return string.sub(s, i + 1, j - 1)
end

return M