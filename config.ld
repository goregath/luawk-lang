title = "AWK for Lua"
project = "AWK for Lua"
file = { "src" }
format = "markdown"
no_space_before_args = true

local upat = "http://www.kernel.org/doc/man-pages/online/pages/man%s/%s.%s.html"

custom_see_handler('^([%w_]+)%((%d)(p?)%)$', function(name,section,subsection)
    local url = upat:format(section,name,section..subsection)
    local name = name .. '(' ..section..subsection..')'
    return name, url
end)