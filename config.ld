title = "AWK for Lua"
project = "AWK for Lua"
package = "luawk"
file = "src"
readme = "README.md"

sort = true
format = "markdown"
no_space_before_args = true

custom_tags = {
	{ "runtime", title = "Runtimes" }
}

kind_names={
	script = 'Program'
}

examples = {
	"examples/plugins"
}

new_type("runtime", "Runtimes", true)
new_type("exported", "Exported Symbols", false)

custom_tags = { { 'virtual', hidden = true } }

custom_see_handler('^([%w_]+)%((%d)(p?)%)$', function(name,section,subsection)
	local upat = "http://www.kernel.org/doc/man-pages/online/pages/man%s/%s.%s.html"
	local url = upat:format(section,name,section..subsection)
	name = name .. '(' ..section..subsection..')'
	return name, url
end)

custom_display_name_handler = function(item, default_handler)
	if item.type == 'field' then
		local name = item.name
		if item.name:match("^%d+$") then
			name = name.format("%s ($%s)", name, name)
		end
		if item.name:find("^%d+%.%.%w+$") then
			local a,b = item.name:match("^(%d+)%.%.(%w+)$")
			name = name.format("%s..%s ($%s..$%s)", a, b, a ,b)
		end
		if item.tags.virtual then
			name = name .. " (virtual)"
		end
		return name
	end
	return default_handler(item)
end