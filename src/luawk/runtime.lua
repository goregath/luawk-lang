--- Luawk default runtime.
--
-- You can test the environment from command-line using the following command:
--     lua -e 'require("luawk.runtime").new(_ENV)' -i
--     Lua 5.4.4  Copyright (C) 1994-2022 Lua.org, PUC-Rio
--     > OFS=","
--     > _ENV[0]="a b c"
--     > NF
--     3
--     > _ENV[NF+1]="d"
--     > NF
--     4
--     > for i,v in ipairs(_ENV) do print(i,v) end
--     1,a
--     2,b
--     3,c
--     4,d
--
-- @usage require("luawk.runtime").new()
-- @alias M
-- @module runtime
-- @see posix
-- @see gnu

local log = require 'luawk.log'
local M = require "luawk.runtime.posix"

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=Runtime]
--  @see posix
--  @function M.new

local function splitR(R, self)
    R.nf = self.split(R[0], R, self.FS)
    log.trace("    [*]=%s <rebuilt>\n", R)
end

local function joinR(R, self)
    local ofs = tostring(self.OFS)
    -- build $0 from $1..$NF
    rawset(R, 0, table.concat(self, ofs, 1, R.nf))
    log.trace("    [0]=%s <rebuilt>\n", R[0])
end

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=Runtime]
function M.new2(rtclass)
    -- TODO R should use weak references
    local R = {
        [0] = "",
        nf = 0,
        split = splitR,
        join = joinR,
    }
    obj = obj or {}
    local runtime = setmetatable({}, {
        class = rtclass,
        record = R,
        __index = function(self,k)
            log.debug("get [%s]\n", k)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                if idx == 0 and R[0] == nil then
                    -- (re)build record from fields
                    R:join(self)
                end
                local val = nil
                if idx <= R.nf then
                    val = R[idx] or ""
                end
                log.trace("    [%s]=%s <record>\n", k, val)
                return val
            end
            if k == "NF" then
                log.trace("    [%s]=%s <record>\n", k, R.nf)
                return R.nf
            end
            local val = rtclass[k]
            if type(val) == "function" then
                -- wrap function self
                local proxy = function(...)
                    return val(self, ...)
                end
                log.trace("    [%s]=%s <default> (%s)\n", k, proxy, val)
                rawset(self, k, proxy)
                return proxy
            end
            if val ~= nil then
                log.trace("    [%s]=%s <default>\n", k, val)
                rawset(self, k, val)
                return val
            end
            val = obj[k]
            if val ~= nil then
                log.trace("    [%s]=%s <global>\n", k, val)
                rawset(self, k, val)
                return val
            end
            log.trace("    [%s]=nil <not found>\n", k)
            return nil
        end,
        __newindex = function(self,k,v)
            local idx = tonumber(k)
            if idx and idx >= 0 then
                idx = math.modf(idx)
                log.debug("set [%s]=%s <field>\n", idx, v)
                v = v ~= nil and tostring(v) or ""
                if idx == 0 then
                    rawset(R, 0, v)
                    R:split(self)
                else
                    R.nf = math.max(idx, R.nf)
                    log.trace("    [%s]=%s <field>\n", idx, v)
                    rawset(R, idx, v)
                    -- (re)build record from fields
                    R:join(self)
                end
            elseif k == "NF" then
                log.debug("set [%s]=%s <virtual>\n", k, v)
                local nf = R.nf
                -- ensure NF is always a number
                R.nf = math.max(math.modf(tonumber(v) or 0), 0)
                if nf > R.nf then
                    -- clear fields after NF
                    for i=R.nf+1,nf do
                        log.trace("    [%s]=%s <field>\n", i, nil)
                        R[i] = nil
                    end
                end
                -- (re)build record from fields
                R:join(self)
            else
                log.debug("set [%s]=%s <runtime>\n", k, v)
                rawset(self, k, v)
            end
        end,
        __len = function()
            return R.nf
        end
    })
    if log.level == "trace" then
        return setmetatable({}, {
            __index = function(_,k)
                log.debug("get [%s]\n", k)
                local v = rawget(runtime, k)
                if v ~= nil then
                    log.trace("    [%s]=%s <cached>\n", k, v)
                    return v
                end
                return runtime[k]
            end,
            __newindex = function(_,k,v)
                log.debug("set [%s]=%s\n", k, v)
                runtime[k] = v
            end,
            __len = function()
                return #runtime
            end
        })
    end
    return runtime
end

return M