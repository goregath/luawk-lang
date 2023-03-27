--- Generic stream object.
-- @class generic

local M = {}

--- Set `var` to the next input record from the current input file. If `var`
--  is unspecified, set record to @{0|$0}.
--
--  This form of getline should update the values of `NF`, `NR`, and `FNR`.
--
--  @param[type=string,opt] var  Set variable var to the next input
--   record from the current input file.
--
--  @return[type=boolean] Shall return true for successful input, false for
--   end-of-file and raise an error otherwise.
--
--  @class function
--  @name generic:getline
function M:getline(env)
    local rs = env.RS and env.RS:sub(1,1) or ""
    -- TODO read record delimited by RS
    -- TODO The first character of the string value of RS shall be
    --      the input record separator; a <newline> by default.
    --      If RS contains more than one character, the results
    --      are unspecified.
    -- TODO If RS is null, then records are separated by sequences
    --      consisting of a <newline> plus one or more blank lines,
    --      leading or trailing blank lines shall not result in empty
    --      records at the beginning or end of the input, and a
    --      <newline> shall always be a field separator, no matter
    --      what the value of FS is.
    local rec
    if rs == "\n" then
        rec = self:read()
    elseif rs == "" then
        error("getline: empty RS not implemented")
    else
        error("getline: non-standard RS not implemented")
    end
    if rec == nil then
        return false
    else
        env[0] = rec
    end
    return true
end

local function new(handle)
	return setmetatable(handle, { __index = M })
end

return {
	new = new
}