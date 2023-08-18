#!/usr/bin/env lua

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
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Cs = lpeg.Cs
local Ct = lpeg.Ct

local sp = P(locale.space + V'comment' - P'\n')^0
local newline = P'\n'
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - newline)^0 * newline

-- local Kend = P'end' * noident
local Kand = P'and' * noident
local Kbreak = P'break' * noident
local Kcontinue = P'continue' * noident
local Kdo = P'do' * noident
local Kelse = P'else' * noident
local Kelseif = P'elseif' * noident
local Kfalse = P'false' * noident
local Kfor = P'for' * noident
local Kfunction = P'function' * noident
local Kglobal = P'global' * noident
local Kgoto = P'goto' * noident
local Kif = P'if' * noident
local Kin = P'in' * noident
local Klocal = P'local' * noident
local Knil = P'nil' * noident
local Knot = P'not' * noident
local Kor = P'or' * noident
local Krepeat = P'repeat' * noident
local Kreturn = P'return' * noident
local Kthen = P'then' * noident
local Ktrue = P'true' * noident
local Kuntil = P'until' * noident
local Kwhile = P'while' * noident

-- local Kexit = 'exit' * noident
-- local Kgetline = 'getline' * noident
-- local Knext = 'next' * noident
-- local Knextfile = 'nextfile' * noident
-- local Kprint = 'print' * noident
-- local Kprintf = 'printf' * noident

-- -- AWK builtin functions
-- local Katan2 = P'atan2' * noident
-- local Kclose = P'close' * noident
-- local Kcos = P'cos' * noident
-- local Kexp = P'exp' * noident
-- local Kgsub = P'gsub' * noident
-- local Kindex = P'index' * noident
-- local Kint = P'int' * noident
-- local Klength = P'length' * noident
-- local Klog = P'log' * noident
-- local Kmatch = P'match' * noident
-- local Krand = P'rand' * noident
-- local Ksin = P'sin' * noident
-- local Ksplit = P'split' * noident
-- local Ksprintf = P'sprintf' * noident
-- local Ksqrt = P'sqrt' * noident
-- local Ksrand = P'srand' * noident
-- local Ksub = P'sub' * noident
-- local Ksubstr = P'substr' * noident
-- local Ksystem = P'system' * noident
-- local Ktolower = P'tolower' * noident
-- local Ktoupper = P'toupper' * noident

-- -- GNU AWK builtin functions
-- local Kpatsplit = P'patsplit' * noident

local function quote(s)
	return string.format("%q", s)
end

-- Lua AWK grammar and parser.
-- Based on Patrick Donnelly LPeg recipe:
-- http://lua-users.org/wiki/LpegRecipes
-- @author Patrick Donnelly (https://github.com/batrick)
local grammar = {
	-- TODO support expr in array
	-- TODO support (index) in array
	-- TODO support expr expr (string concatenation)
	-- TODO support for-loop
	-- TODO support autoinit of variables
	-- TODO unary_expr: unary_expr '?' expr ':' expr
	-- TODO unary_expr: unary_expr In NAME
	-- TODO non_unary_expr: '+' expr
	-- TODO non_unary_expr: lvalue INCR
	-- TODO non_unary_expr: lvalue DECR
	-- TODO non_unary_expr: INCR lvalue
	-- TODO non_unary_expr: DECR lvalue
	-- TEST awk '$0 ~ /b/ ~ 1 { print }' <<<"a b c" --> "a b c"

	-- AWK grammar

	-- TODO FIXME object is preserved between multiple lpeg.match
	newobj = Cg(Cc({
		BEGIN = {},
		END = {},
		BEGINFILE = {},
		ENDFILE = {},
		main = {}
	}), 'program');

	shebang^-1 * V'newobj' * ((sp * (V'rule' / table.insert) * (sp * V'eol')^-1)^1)^0 * sp * -1;

	rule =
		  Cb('program') * C(V'specialpattern') / rawget * sp * Cs(V'action')
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * sp * Cs(V'action') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * Cc('print()') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cc('true') * Cs(V'action') )
		;

	pattern =
		  ((V'void' + V'code') - V'eol' - V'action')^1
		- V'specialpattern'
		;

	eol =
		   S';\n'
		;

	void =
		  V'comment'
		+ V'string'
		+ V'parentheses'
		+ V'brackets'
		;

	code =
		  (P'$' * Cs(V'number' + V'name')) / '_ENV[%1]'
		+ (P'$' * Cs(V'parentheses')) / '_ENV[%1]'
		+ 1
		;

	specialpattern =
		  P'BEGINFILE' + 'ENDFILE' + 'BEGIN' + 'END'
		;

	-- TODO $1~/re/
	awkregex =
		  '/' * Cg((P'\\' * P(1) + (1 - P'/'))^0) * '/' / quote / '_ENV.match(_ENV[0],%1)'
		;

	action =
		--   Cc'return' * V'braces' * sp * '->' * sp * V'actionblock'
		-- + Cc'return' * V'brackets' * sp * '->' * sp * V'actionblock'
		-- + Cc'return(_ENV)=>' * V'actionblock'
		  -- Cc'return(_ENV)=>' * V'actionblock'
		  V'actionblock'
		;

	actionblock =
		  ('{' * Cs((V'string' + V'comment' + (V'code' - S'{}') + V'actionblock')^0) * '}') / '%1'
		;

	longstring = C(P{ -- from Roberto Ierusalimschy's lpeg examples
		V'open' * C((P(1) - V'closeeq')^0) * V'close' / function (o, s) return s end;

		open =
			  '[' * Cg((P'=')^0, "init") * '[' * (newline)^-1
			;
		close =
			  ']' * C((P'=')^0) * ']'
			;
		closeeq =
			  Cmt(V'close' * Cb'init', function (s, i, a, b) return a == b end)
	});

	string =
		  '"' * ('\\' * P(1) + (P(1) - '"'))^0 * '"'
		+ "'" * ("\\" * P(1) + (P(1) - "'"))^0 * "'"
		+ V'awkregex'
		+ V'longstring'
		;

	comment =
		  '--' * V'longstring'
		+ '--' * (P(1) - newline)^0 * (newline + -P(1))
		;

	parentheses =
		  '(' * (V'void' + (V'code' - S'()' + V'parentheses'))^0 * ')'
		;

	brackets =
		  '[' * (V'void' + (V'code' - S'[]' + V'brackets'))^0 * ']'
		;

	braces =
		  '{' * (V'void' + (V'code' - S'{}' + V'braces'))^0 * '}'
		;

	number =
		  (P'-')^-1 * sp * '0x' * locale.xdigit^1 * -(locale.alnum + '_')
		+ (P'-')^-1 * sp * locale.digit^1 * ('.' * locale.digit^1)^-1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + '_')
		+ (P'-')^-1 * sp * '.' * locale.digit^1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + '_')
		;

	name =
		  (locale.alpha + '_') * (locale.alnum + '_')^0 - V'keywords'
		;

	keywords =
		  Kand
		+ Kbreak
		+ Kcontinue
		+ Kdo
		+ Kelse
		+ Kelseif
		+ Kfalse
		+ Kfor
		+ Kfunction
		+ Kglobal
		+ Kgoto
		+ Kif
		+ Kin
		+ Klocal
		+ Knil
		+ Knot
		+ Kor
		+ Krepeat
		+ Kreturn
		+ Kthen
		+ Ktrue
		+ Kuntil
		+ Kwhile
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