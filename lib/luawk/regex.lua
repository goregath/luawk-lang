--- Luawk regex functions.
-- @alias M
-- @module regex

local M = {}

--- Find function used by luawk environments (`luawk.environment.*`).
--
--  This function can be used by any luawk `Runtime` function to implement
--  pattern matching facilities like `posix.match`, `posix.split` or `GNU.patsplit`.
--
--  By default, this function is an alias for `string.find` and thus uses lua
--  pattern matching.
--
--  @usage
--      > find = require 'luawk.regex'.find
--      > find("0123456789abcdef", "%D+")   -- match
--      11	16
--      > find("0123456789abcdef", "%X")    -- no match
--      nil
--      > find("0123456789abcdef", "%X*")   -- empty match
--      1	0
--
--  @param[type=string] s input string
--  @param[type=string] pattern search pattern
--  @param[type=number,opt=1] init specifies where to start the search, its
--   default value is 1 and can be negative
--  @return[1,type=number] If it finds a match, then find returns the indices of
--   s where this occurrence starts and ends; otherwise, it returns nil. If
--   the pattern has captures, then in a successful match the captured values
--   are also returned, after the two indices.
--  @return[2,type=nil]
--
--  @function find
--  @see string.find
--  @see posix.match
--  @see posix.split
--  @see gnu.patsplit
M.find = string.find

return M