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
-- @usage require("luawk.runtime").new(_ENV or _G)
-- @alias M
-- @module runtime
-- @see POSIX
-- @see GNU
-- @license MIT

local M = require "luawk.runtime.posix"

--- Create a new object.
--  @param[type=table,opt] obj
--  @return[type=Runtime]
--  @see POSIX
--  @function M.new

return M