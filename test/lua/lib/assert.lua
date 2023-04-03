local M = {}

function M.assert_true(test)
	if not test then
		error(string.format("assert_equal: expected true, was %q", test), 2)
	end
end

function M.assert_type(test, expected)
	if type(test) ~= expected then
		error(string.format("assert_equal: expected %q, was %q", expected, test), 2)
	end
end

function M.assert_equal(test, expected)
	if test ~= expected then
		error(string.format("assert_equal: expected %q, was %q", expected, test), 2)
	end
end

function M.assert_re(test, pattern)
	if not string.match(test, pattern) then
		error(string.format("assert_re:  %q did not match %q", test, pattern), 2)
	end
end

function M.assert_error(f, pattern)
	local s, m = pcall(f)
	if s ~= false then
		error("assert_error: succeeded")
	end
	if pattern ~= nil then
		M.assert_re(m, pattern)
	end
end

return M