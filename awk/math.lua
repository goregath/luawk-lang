--- AWK math functions.
-- @alias M
-- @module math

--[[
The arithmetic functions, except for int, shall be based on the ISO C
standard (see Concepts Derived from the ISO C Standard). The behavior
is undefined in cases where the ISO C standard specifies that an error
be returned or that the behavior is undefined. Although the grammar
(see Grammar) permits built-in functions to appear with no arguments
or parentheses, unless the argument or parentheses are indicated as
optional in the following list (by displaying them within the "[]"
brackets), such use is undefined.

    atan2(y,x)
        Return arctangent of y/x in radians in the range [-,].
    cos(x)
        Return cosine of x, where x is in radians.
    sin(x)
        Return sine of x, where x is in radians.
    exp(x)
        Return the exponential function of x.
    log(x)
        Return the natural logarithm of x.
    sqrt(x)
        Return the square root of x.
    int(x)
        Return the argument truncated to an integer.
        Truncation shall be toward 0 when x>0.
    rand()
        Return a random number n, such that 0<=n<1.
    srand([expr])
        Set the seed value for rand to expr or use the time of day if expr is omitted.
        The previous seed value shall be returned.
]]--

local M = {}

return M