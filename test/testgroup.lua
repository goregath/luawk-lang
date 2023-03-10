local ansi_green = "\27[32;1m"
local ansi_red   = "\27[31;1m"
local ansi_reset = "\27[0m"

local M = {}

function M:setup(setup)
	self.testsetup = setup
end

function M:teardown(teardown)
	self.testteardown = teardown
end

function M:add(label, test)
	table.insert(self, table.pack(label, test))
end

function M:run()
	local failed = {}
	io.stdout:write(ansi_green)
	io.stdout:write(string.format("1..%d", #self))
	io.stdout:write(ansi_reset)
	io.stdout:write(string.format(" # %s\n", self.name))
	self.testsetup = self.testsetup or function() end
	self.testteardown = self.testteardown or function() end
	for i,test in ipairs(self) do
		local status, msg = pcall(function()
			local env = self:testsetup()
			test[2](env)
			self:testteardown(env)
		end)
		if status then
			io.stdout:write(ansi_green, "ok", ansi_reset)
			io.stdout:write(string.format(" %d %s\n", i, test[1]))
		else
			table.insert(failed, i)
			io.stdout:write(ansi_red, "not ok", ansi_reset)
			io.stdout:write(string.format(" %d %s\n  %s\n", i, test[1], tostring(msg):gsub("\n", "\n  ")))
		end

	end
	-- if #failed > 0 then
	-- 	io.stdout:write(ansi_red)
	-- 	io.stdout:write("FAILED tests ", table.concat(failed, ", "), "\n")
	-- 	io.stdout:write(string.format(
	-- 		"Failed %d/%d tests, %.2f%% okay\n",
	-- 		#failed, #self,
	-- 		100 - (#self / #failed * 100)
	-- 	))
	-- 	io.stdout:write(ansi_reset)
	-- end
end

function M.new(name)
	return setmetatable({ name = name }, { __index = M })
end

return M