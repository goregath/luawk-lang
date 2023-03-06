--- Luawk regex functions.
-- @alias M
-- @module regex
-- @license MIT

local M = {}

--- Find function used by luawk runtimes (`luawk.runtime.*`).
--
--  This function can be used by any luawk `Runtime` function to implement
--  pattern matching facilities like `POSIX.match`, `POSIX.split` or `GNU.patsplit`.
--
--  By default, this function is an alias for `string.find` and thus uses lua
--  pattern matching.
--
--  @param[type=string] s input string
--  @param[type=string] pattern search pattern
--  @param[type=number,opt] init specifies where to start the search, its
--   default value is 1 and can be negative
--  @return[type=number] if the pattern has captures, then in a successful
--   match the captured values are also returned, after the two indices.
--
--  @function find
M.find = string.find

return M