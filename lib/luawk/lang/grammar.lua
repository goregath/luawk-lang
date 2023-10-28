#!/usr/bin/env lua

---
-- @alias M
-- @module grammar

-- ╔═══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ Expressions in Decreasing Precedence in awk                                                   ║
-- ╠════════════════════════╦═══════════════════════════════════╦══════════════════╦═══════════════╣
-- ║ SYNTAX                 ║ NAME                              ║ TYPE OF RESULT   ║ ASSOCIATIVITY ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ (expr)                 ║ Grouping                          ║ Type of expr     ║ N/A           ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ $expr                  ║ Field reference                   ║ String           ║ N/A           ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ lvalue ++              ║ Post-increment                    ║ Numeric          ║ N/A           ║
-- ║ lvalue --              ║ Post-decrement                    ║ Numeric          ║ N/A           ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ ++ lvalue              ║ Pre-increment                     ║ Numeric          ║ N/A           ║
-- ║ -- lvalue              ║ Pre-decrement                     ║ Numeric          ║ N/A           ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr ^ expr            ║ Exponentiation                    ║ Numeric          ║ Right         ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ ! expr                 ║ Logical not                       ║ Numeric          ║ N/A           ║
-- ║ + expr                 ║ Unary plus                        ║ Numeric          ║ N/A           ║
-- ║ - expr                 ║ Unary minus                       ║ Numeric          ║ N/A           ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr * expr            ║ Multiplication                    ║ Numeric          ║ Left          ║
-- ║ expr / expr            ║ Division                          ║ Numeric          ║ Left          ║
-- ║ expr % expr            ║ Modulus                           ║ Numeric          ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr + expr            ║ Addition                          ║ Numeric          ║ Left          ║
-- ║ expr - expr            ║ Subtraction                       ║ Numeric          ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr expr              ║ String concatenation              ║ String           ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr < expr            ║ Less than                         ║ Numeric          ║ None          ║
-- ║ expr <= expr           ║ Less than or equal to             ║ Numeric          ║ None          ║
-- ║ expr != expr           ║ Not equal to                      ║ Numeric          ║ None          ║
-- ║ expr == expr           ║ Equal to                          ║ Numeric          ║ None          ║
-- ║ expr > expr            ║ Greater than                      ║ Numeric          ║ None          ║
-- ║ expr >= expr           ║ Greater than or equal to          ║ Numeric          ║ None          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr ˜ expr            ║ ERE match                         ║ Numeric          ║ None          ║
-- ║ expr !˜ expr           ║ ERE non-match                     ║ Numeric          ║ None          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr in array          ║ Array membership                  ║ Numeric          ║ Left          ║
-- ║ (index) in array       ║ Multi-dimension array membership  ║ Numeric          ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr && expr           ║ Logical AND                       ║ Numeric          ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr || expr           ║ Logical OR                        ║ Numeric          ║ Left          ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ expr1 ? expr2 : expr3  ║ Conditional expression            ║ Type of selected ║ Right         ║
-- ║                        ║                                   ║ expr2 or expr3   ║               ║
-- ╠════════════════════════╬═══════════════════════════════════╬══════════════════╬═══════════════╣
-- ║ lvalue ^= expr         ║ Exponentiation assignment         ║ Numeric          ║ Right         ║
-- ║ lvalue %= expr         ║ Modulus assignment                ║ Numeric          ║ Right         ║
-- ║ lvalue *= expr         ║ Multiplication assignment         ║ Numeric          ║ Right         ║
-- ║ lvalue /= expr         ║ Division assignment               ║ Numeric          ║ Right         ║
-- ║ lvalue += expr         ║ Addition assignment               ║ Numeric          ║ Right         ║
-- ║ lvalue -= expr         ║ Subtraction assignment            ║ Numeric          ║ Right         ║
-- ║ lvalue = expr          ║ Assignment                        ║ Type of expr     ║ Right         ║
-- ╚════════════════════════╩═══════════════════════════════════╩══════════════════╩═══════════════╝

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

local nl = P'\n'
local blank = P(locale.space + V'comment' - nl)
local sp = blank^0
local eol = (P';' + nl)^1
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - nl)^0 * nl

local function awkregexunquote(s)
	return string.format("%q", s):gsub("\\\\", "\\"):gsub("\\/", "/")
end

local token = {
	["in"] = "in",
	["!"] = "not",
	-- ["*"] = "mul",
	-- ["%"] = "fmod",
	-- ["/"] = "div",
	-- ["//"] = "floordiv",
	-- ["^"]  = "pow",
	["<"]  = "lt",
	[">"]  = "gt",
	["<="] = "le",
	[">="] = "ge",
	["!="] = "ne",
	["=="] = "eq",
	["&&"] = "and",
	["||"] = "or",
	["~"] = "match",
	["!~"] = "match",
}
local function eval(acc,op,v)
	local fn = token[op]
	if fn then
		if op == "!~" then
			return string.format("%s(%s(%s,%s))", token["!"], fn, acc, v)
		end
		if op == "!" then
			return string.format("%s(%s)", fn, v)
		end
		return string.format("%s(%s,%s)", fn, acc, v)
	end
	return string.format("%s%s%s", acc, op, v)
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

	shebang^-1 * V'newobj' * (blank + nl)^0 * (
		  ( ( V'globals' / table.insert * (blank + eol)^0 )^1 )^0
		* ( ( V'rule' / table.insert * (blank + eol)^0 )^1 )^0 * sp * -1
	);

	globals =
		  Cb('program') * Cc('BEGIN') / rawget * Cs(V'function')
		;

	rule =
		  Cb('program') * C(V'specialpattern') / rawget * sp * Cs(V'action')
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * (P',' * sp * Cs(V'pattern'))^-1 * sp * Cs(V'action') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cs(V'pattern') * (P',' * sp * Cs(V'pattern'))^-1 * Cc('print()') )
		+ Cb('program') * Cc('main') / rawget * Ct( Cc(true) * Cs(V'action') )
		;

	pattern =
		  V'exp'
		- V'specialpattern'
		;

	specialpattern =
		  P'BEGINFILE'
		+ P'ENDFILE'
		+ P'BEGIN'
		+ P'END'
		;

	action =
		  V'actionblock'
		;

	actionblock =
		  Cg('{' * sp * Cs(V'chunk') * sp * '}')
		;

	explist =
		  V'exp' * (sp * P',' * sp * V'exp')^0 * sp
		;

	namelist =
		  V'name' * (sp * P',' * sp * V'name')^0 * sp
		;

	-- TODO ++a--
	-- TODO ambiguous syntax: {}

	exp =
		  Cf(V'tier11' * Cg(C(S'^%*/+-'^-1 * P'=') * sp * V'tier11')^0, eval)
		;

	-- ternary operator / conditional expression
	tier11 =
		  Cf(Cf(V'tier10' * Cg(Cs(P'?'/'&&') * sp * V'tier10'), eval) * sp * Cg(Cs(P':'/'||') * sp * V'tier10'), eval)
		+ V'tier10';
	tier10 = Cf(V'tier09' * Cg(C(P'||') * sp * V'tier09')^0, eval);
	tier09 = Cf(V'tier08' * Cg(C(P'&&') * sp * V'tier08')^0, eval);
	tier08 = Cf(V'tier07' * Cg(C(P'in') * sp * V'tier07')^0, eval);
	tier07 = Cf(V'tier06' * Cg(C(P'!~' + P'~') * sp * (V'awkregex' + V'tier06'))^0, eval);
	tier06 = Cf(V'tier05' * Cg(C(S'<>!=' * P'=' + S'<>') * sp * V'tier05')^0, eval);
	-- TODO 'expr expr' (AWK, left-associative) 'expr .. expr' (Lua, right-associative)
	tier05 = Cf(V'tier04' * Cg(Cc('..') * sp * V'tier04')^0, eval);
	tier04 = Cf(V'tier03' * Cg(C(S'+-') * sp * V'tier03')^0, eval);
	tier03 = Cf(V'tier02' * Cg(C(P'//' + S'*/%') * sp * V'tier02')^0, eval);
	-- binary operators
	tier02 =
		  Cg(Cc(nil) * sp * C(P'!') * sp * Cs(V'tier01')) / eval * sp
		+ Cs(P'-' * sp * V'tier01') * sp
		+ V'tier01';
	tier01 = Cf(Cs(V'tier00') * Cg(C(S'^') * sp * Cs(V'tier00'))^0, eval);
	tier00 = Cg(Cs(V'value') * sp * (C(S'-=' * P'>') * sp * Cs(V'value'))^0);

	value =
		  V'simple' * (sp * V'subvalue')^0
		+ V'subvalue'
		+ V'awkbuiltins' * sp * P'(' * sp * V'explist'^0 * sp * P')'
		+ V'awkbuiltins' * sp * Cc'(' * V'explist'^0 * sp * Cc')'
		+ V'awkbuiltins' * Cc'()'
		+ V'awkfieldref'
		;

	subvalue =
		  S'.:' * sp * V'name' * sp * P'(' * sp * V'explist'^0 * sp * P')'
		+ P'[' * sp * V'explist'^0 * sp * P']'
		+ P'(' * sp * V'explist'^0 * sp * P')'
		+ P'.' * sp * V'value'
		;

	simple =
		  locale.digit * locale.alnum^0
		+ V'string'
		+ V'name'
		+ P'nil'
		+ P'true'
		+ P'false'
		;

	chunk =
		  V'source'^0
		;

	source =
		 '{' * sp * V'chunk' * sp * '}'
		+ P'for' * noident * sp * (V'namelist'^1 + P(-1)) * sp * P'in' * noident * sp * V'source'
		+ V'explist'
		+ V'keyword'
		+ blank
		+ eol
		;

	["function"] =
		  P'function' * noident * blank^1
		* (V'name' + V'awkbuiltins') * sp * '(' * sp * V'explist'^0 * sp * ')' * sp
		* '{' * sp * V'chunk' * sp * '}'
		;

	keyword =
		  P'break' * noident
		+ P'do' * noident
		+ P'else' * noident
		+ P'elseif' * noident
		+ P'end' * noident
		+ P'false' * noident
		+ P'for' * noident
		+ P'function' * noident
		+ P'goto' * noident
		+ P'if' * noident
		+ P'in' * noident
		+ P'local' * noident
		+ P'nil' * noident
		+ P'repeat' * noident
		+ P'return' * noident
		+ P'then' * noident
		+ P'true' * noident
		+ P'until' * noident
		+ P'while' * noident
		+ V'awkbuiltins'
		;

	name =
		  (locale.alpha + '_') * (locale.alnum + '_')^0 - V'keyword'
		+ P'...' * sp * V'name'^0
		+ P'$@' / '_ENV'
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

	-- TODO support string interpolations
	string =
		  P'"' * ('\\' * P(1) + (P(1) - '"'))^0 * P'"'
		+ P"'" * ("\\" * P(1) + (P(1) - "'"))^0 * P"'"
		+ V'awkregex' / 'match(_ENV[0],%1)'
		+ V'longstring'
		;

	comment =
		  '#' * (P(1) - nl)^0 * (nl + -P(1)) / '\n'
		;

	awkbuiltins =
		  P'exit' * noident
		+ P'getline' * noident
		+ P'next' * noident
		+ P'nextfile' * noident
		+ P'print' * noident
		+ P'printf' * noident
		;

	awkfieldref =
		  P'$' * sp * Cs(V'value') / '_ENV[%1]'
		;

	awkregex =
		  '/' * Cs((P'\\' * P(1) + (1 - P'/'))^0) * '/' / awkregexunquote
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

-- if (...) ~= "luawk.lang.grammar" then
-- 	local ins = require 'inspect'
-- 	for _,chunk in ipairs(arg) do
-- 		local program, msg, _, line, col = M.parse(chunk)
-- 		print(chunk)
-- 		print(('-'):rep(#chunk < 8 and 8 or #chunk))
-- 		if program then
-- 			io.stdout:write(ins(program), "\n")
-- 		else
-- 			io.stderr:write("error: ", msg, " at line ", line or "?", " col ", col or "?", "\n")
-- 		end
-- 	end
-- end

return M
