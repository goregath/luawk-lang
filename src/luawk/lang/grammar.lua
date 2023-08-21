#!/usr/bin/env lua

---
-- @alias M
-- @module grammar

local M = {}

local lpeg = require 'lpeglabel'
local re = require 'relabel'
local locale = lpeg.locale();

local P, S, V = lpeg.P, lpeg.S, lpeg.V

local C = lpeg.C
local Cb = lpeg.Cb
local Cc = lpeg.Cc
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Cs = lpeg.Cs
local Ct = lpeg.Ct

local nl = P'\n'
local sp = P(locale.space + V'comment' - nl)^0
local eol = P';' + nl
local deref = P'$' / '_ENV^'
local shebang = P"#" * (P(1) - nl)^0 * nl

local function quote(s)
	return string.format("%q", s)
end

-- TODO proper comment and line break handling
-- TODO pattern,pattern to range-pattern
-- TEST awk '$0 ~ /b/ ~ 1 { print }' <<<"a b c" --> "a b c"
local grammar = {
	-- TODO FIXME object is preserved between multiple lpeg.match
	newobj = Cg(Cc({
		BEGIN = {},
		END = {},
		BEGINFILE = {},
		ENDFILE = {},
		main = {}
	}), 'program');

	shebang^-1 * V'newobj' * (((V'rule' / table.insert) * (sp * eol)^-1)^1)^0 * sp * -1;

	rule =
		  Cb('program') * C(V'specialpattern') / rawget * sp * Cs(V'action')
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * sp * Cs(V'action') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * Cc('print()') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cc('true') * Cs(V'action') )
		;

	pattern =
		  V'exp'
		- V'specialpattern'
		- #P'{'
		;

	specialpattern =
		  P'BEGINFILE'
		+ P'ENDFILE'
		+ P'BEGIN'
		+ P'END'
		;

	awkregex =
		  '/' * Cg((P'\\' * P(1) + (1 - P'/'))^0) * '/' / quote
		;

	action =
		  V'actionblock' * sp * -#V'binop'
		;

	actionblock =
		  ('{' * sp * Cs(V'chunk') * sp * '}') / '%1'
		;

	subscript =
		  '[' * sp * V'exp'^-1 * sp * ']'
		;

	value =
		  deref^0 * (locale.alnum + '_')^1
		+ deref^0 * V'string'
		+ deref^0 * '{' * sp * V'chunk' * sp * '}'
		+ deref^0 * '(' * sp * V'exp'^-1 * sp * ')'
		+ V'subscript'
		;

	lvalue =
		  P'$' * Cs(V'value' * V'subscript'^0) / '_ENV[%1]'
		+ V'value' * V'subscript'^0
		;

	ctlchr =
		  1 - S'(){}[]' - V'value' - eol - V'comment'
		;

	assignop =
		  V'ctlchr'^-1 * P'='
		- S'=!<>' * P'='
		;

	binop =
		  (V'ctlchr'^2 - V'assignop')
		+ (V'ctlchr' - P'=')
		;

	exp =
		  V'binop' * sp * V'exp'
		+ V'lvalue' * (sp * ',' * sp * V'lvalue')^0 * sp * (P'=' + V'assignop') * sp * V'exp'
		+ V'value' * sp * #S'([' * sp * V'exp'
		+ V'value' * (sp * V'binop'^1 * sp * V'exp')^-1
		+ V'value'
		;

	chunk =
		  (V'exp' + eol)^0
		;

	longstring = C(P{ -- from Roberto Ierusalimschy's lpeg examples
		V'open' * C((P(1) - V'closeeq')^0) * V'close' / function (_, s) return s end;

		open =
			  '[' * Cg((P'=')^0, "init") * '[' * (nl)^-1
			;
		close =
			  ']' * C((P'=')^0) * ']'
			;
		closeeq =
			  Cmt(V'close' * Cb'init', function (_, _, a, b) return a == b end)
	});

	string =
		  '"' * ('\\' * P(1) + (P(1) - '"'))^0 * '"'
		+ "'" * ("\\" * P(1) + (P(1) - "'"))^0 * "'"
		+ V'awkregex'
		+ V'longstring'
		;

	comment =
		  '--' * V'longstring'
		+ '--' * (P(1) - nl)^0 * (nl + -P(1))
		;
};

--- Program data type.
--  @field[type=callable] BEGIN
--  @field[type=callable] BEGINFILE
--  @field[type=callable] END
--  @field[type=callable] ENDFILE
--  @field[type=callable] main
--  @table Program

--- Parse luawk source string.
--  @param[type=string]  source input string
--  @return[1,type=Program]
--  @return[2,type=nil] generic error
--  @return[2,type=string] error message
--  @return[3,type=false] parser error
--  @return[3,type=string] error message
--  @return[3,type=number] position in source
--  @return[3,type=number] source line
--  @return[3,type=number] source column
--  @function M.parse
function M.parse(source)
	local lang = Ct(P(grammar))
	local stat, obj, _, pos = pcall(lpeg.match, lang, source)
	if not stat then
		return nil, obj, nil, nil, nil
	end
	if not obj then
		return false, "syntax error", pos, re.calcline(source, pos)
	else
		return obj
	end
end

if (...) ~= "luawk.lang.grammar" then
	local ins = require 'inspect'
	for _,chunk in ipairs(arg) do
		local program, msg, _, line, col = M.parse(chunk)
		print(chunk)
		print(('-'):rep(#chunk < 8 and 8 or #chunk))
		if program then
			io.stdout:write(ins(program), "\n")
		else
			io.stderr:write("error: ", msg, " at line ", line or "?", " col ", col or "?", "\n")
		end
	end
end

return M