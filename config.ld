title = "AWK for Lua"
project = "AWK for Lua"
package = "luawk"
file = "src"
readme = "README.md"

sort = true
format = "markdown"
no_space_before_args = true

kind_names={
	script = 'Program'
}

examples = {
	"examples/plugins"
}

alias("TODO","todo")
alias("FIXME","fixme")
alias("WARNING","warning")
alias("BUG","fixme")

new_type("runtime", "Runtimes", true)

custom_tags = {
	{ "label", hidden = true },
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
	local name = item.name
	if item.tags.label then
		name = name .. " <sup>("
		for _,label in ipairs(item.tags.label) do
			name = name .. label .. ", "
		end
		name = name:sub(1,-3) .. ")</sup>"
	end
	if name ~= item.name then
		return name
	end
	return default_handler(item)
end