--- Luawk utility functions.
-- @alias M
-- @module utils
-- @license MIT

local lua_version = _VERSION:sub(-3)
local M = {
    --- Character pattern matching UTF-8.
    utf8charpattern = utf8.charpattern
}

if lua_version == "5.1" then
    M.utf8charpattern = "[%z\1-\127\194-\244][\128-\191]*"
elseif lua_version == "5.2" then
    M.utf8charpattern = "[\0-\127\194-\244][\128-\191]*"
end

--- Check if argument is indexable.
--  @param a test subject
function M.isarray(a)
    local type = type(a)
    if type == "table" then return true end
    local mt = getmetatable(a)
    return mt and mt.__len and mt.__index and true
end

--- Print arguments to `io.stderr` using `string.format` and call `os.exit`(`1`).
--  @param ... arguments for `string.format`
function M.abort(...)
    io.stderr:write(string.format(...))
    os.exit(1)
end

--- Pass arguments to `error` using `string.format`.
--  @param ... arguments for `string.format`
function M.fail(...)
    error(string.format(...), -1)
end

local function info(...)
    io.stderr:write("info: ", string.format(...))
end
M.info = info

local function dbgmsg(...)
    local fmt = ...
    local argc = select('#', ...)
    local argv = { select(2, ...) }
    local varg = setmetatable({}, {
        __index = function(_,k) return argv[k] ~= nil and string.format("%q", tostring(argv[k])) or "<nil>" end,
        __len = function() return argc end
    })
    io.stderr:write("debug: ", string.format(fmt, table.unpack(varg)))
end
M.dbgmsg = dbgmsg

--- Iterates over arguments and returns the first module it could find.
--  @param ... modnames (see `require`)
function M.requireany(...)
    local pkgname
    for _,v in ipairs{...} do
        info("require %q ...", v)
        pkgname = v
        local loaded, lib, where = pcall(require, pkgname)
        if loaded then
            info(" found at %q\n", where or package.searchpath(pkgname, package.path))
            return lib
        end
        info(" not found\n", v)
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

--- Compatibility layer setfenv() for Lua 5.2+.
--  Taken from Penlight Lua Libraries (lunarmodules/Penlight).
--  @function setfenv
M.setfenv = _G.setfenv or function(f, t)
    local var
    local up = 0
    repeat
        up = up + 1
        var = debug.getupvalue(f, up)
    until var == '_ENV' or var == nil
    if var then
        debug.upvaluejoin(f, up, function() return var end, 1) -- use unique upvalue
        debug.setupvalue(f, up, t)
    end
    if f ~= 0 then return f end
end

return M