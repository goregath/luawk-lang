title = "AWK for Lua"
project = "AWK for Lua"
package = "luawk"
file = "src"
readme = "README.md"

one = true
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

custom_see_handler('^([%w_]+)%((%d)(p?)%)$', function(name,section,subsection)
	local upat = "http://www.kernel.org/doc/man-pages/online/pages/man%s/%s.%s.html"
	local url = upat:format(section,name,section..subsection)
	name = name .. '(' ..section..subsection..')'
	return name, url
end)
