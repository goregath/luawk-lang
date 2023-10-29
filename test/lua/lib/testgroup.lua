local getenv = require "posix.stdlib".getenv
local isatty = require "posix.unistd".isatty
local term = getenv("TERM")

local ansi_green = ""
local ansi_red = ""
local ansi_reset = ""

if isatty(1) and term and term ~= "dumb" then
	ansi_green = "\27[32;1m"
	ansi_red   = "\27[31;1m"
	ansi_reset = "\27[0m"
end

local M = {}

function M:setup(setup)
	self.testsetup = setup
end

function M:teardown(teardown)
	self.testteardown = teardown
end

function M:add(label, test)
	local obj = table.pack(label, test)
	obj.skip = false
	table.insert(self, obj)
end

function M:skip(label, test, reason)
	local obj = table.pack(label, test)
	obj.skip = true
	obj.reason = reason
	table.insert(self, obj)
end

function M:run(noexit)
	local failed = {}
	io.stdout:write(ansi_green)
	io.stdout:write(string.format("1..%d\n", #self))
	-- io.stdout:write(ansi_reset)
	-- io.stdout:write(string.format("# %s\n", self.name))
	self.testsetup = self.testsetup or function() end
	self.testteardown = self.testteardown or function() end
	for i,test in ipairs(self) do
		if test.skip then
			io.stdout:write(ansi_green, "ok", ansi_reset)
			io.stdout:write(string.format(" %d - %s # SKIP %s\n", i, test[1], test.reason or ""))
		else
			local status, msg = pcall(function()
				local env = table.pack(self:testsetup())
				test[2](table.unpack(env))
				self:testteardown(table.unpack(env))
			end)
			if status then
				io.stdout:write(ansi_green, "ok", ansi_reset)
				io.stdout:write(string.format(" %d - %s\n", i, test[1]))
			else
				table.insert(failed, i)
				io.stdout:write(ansi_red, "not ok", ansi_reset)
				io.stdout:write(string.format(" %d - %s\n  %s\n", i, test[1],
					tostring(msg):gsub("\n%s*$", ""):gsub("\n", "\n  ")))
			end
		end
	end
    if noexit then
	    return #failed == 0
    else
        os.exit(#failed == 0 and 0 or 1)
    end
end

function M.new(name)
	return setmetatable({ name = name }, { __index = M })
end

return M
