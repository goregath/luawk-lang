title = "AWK for Lua"
project = "AWK for Lua"
package = "luawk"
file = "src"
readme = "README.md"
style = true

sort = true
format = "markdown"
no_space_before_args = true

kind_names={
	script = 'Program'
}

-- pretty = 'pycco'
-- examples = {
-- 	"examples/plugins/",
-- }

alias("TODO","todo")
alias("FIXME","fixme")
alias("WARNING","warning")
alias("BUG","fixme")

new_type("runtime", "Runtimes", true)

custom_tags = {
	-- { "label", hidden = true },
	-- { "methodof", hidden = true },
	{ "fieldof", hidden = true },
	{ "default", hidden = false },
	{ "depends", title = "Depends" },
}

custom_see_handler('^([%w_]+)%((%d)(p?)%)$', function(name,section,subsection)
	local upat = "http://www.kernel.org/doc/man-pages/online/pages/man%s/%s.%s.html"
	local url = upat:format(section,name,section..subsection)
	name = name .. '(' ..section..subsection..')'
	return name, url
end)

custom_see_handler('^([%w.]+)%s+(.*)$', function(module, url)
	return module, url
end)

custom_display_name_handler = function(item, default_handler)
	-- if item.usage then
	-- 	for i,usage in ipairs(item.usage) do
	-- 		if usage:match("^%$") then
	-- 			item.usage[i] = io.popen(usage)
	-- 		end
	-- 	end
	-- end
	local name = item.name
	if item.tags.fieldof then
		name = default_handler(item)
		name = ("<code>%s[</code>%s<code>]</code>"):format(item.tags.fieldof[1] or "???", name)
	elseif item.type == "field" or item.type == "function" or item.type == "table" then
		name = default_handler(item)
		if name:find("[.:]") then
			name = ("<code>%s</code>%s%s"):format(name:match("([^.:]*)([.:])(.*)"))
		end
	end
	-- if item.tags.default then
	-- 	name = ("%s<small> = %s</small>"):format(name, item.tags.default[1]:match("%W*(%S+)"))
	-- end
	if name ~= item.name then
		return name
	end
	return default_handler(item)
end