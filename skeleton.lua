-- @Author: Oliver Zimmer
-- @Date:   2023-02-20 11:22:41
-- @Last Modified by:   Oliver.Zimmer@e3dc.com
-- @Last Modified time: 2023-02-20 15:36:11

function doexit(s)
	coroutine.yield("exit", s or 0)
end

function donext()
	coroutine.yield("next")
end

local actions = {}
local files = {}

do
	local tbl = actions
	for _,v in ipairs(arg) do
		if v == "--" then
			tbl = files
		else
			table.insert(tbl, v)
		end
	end
	for i=1,#actions do
		actions[i] = assert(load(actions[i]))
	end
end

-----------------------------------------------------------
-- MAIN
-----------------------------------------------------------

if warn == nil then
	warn = function(...) io.stderr:write("warning: ", ..., "\n") end
else
	warn("@on")
end

local function program(handle)
	local record = handle:read()
	while record do
		for _,action in ipairs(actions) do
			action(record)
		end
		record = handle:read()
	end
	return "nextfile"
end

local stat, yield, data
for _, file in ipairs(files) do
	local handle = assert(io.open(file))
	local body = coroutine.wrap(program)
	while true do
		stat, yield, data = pcall(body, handle)
		-- io.stderr:write(string.format("%s: %s,%s,%s\n",file,stat,yield,data))
		if (not stat) then
			error(yield, 2)
		end
		if yield == "next" then
			body = coroutine.wrap(program)
		elseif yield == "nextfile" then
			break
		elseif yield == "exit" then
			break
		else
			warn(string.format("unknown yield value: %q", yield))
		end
	end
	pcall(io.close, handle)
	if yield == "exit" then
		break
	end
end
os.exit(data or 0)