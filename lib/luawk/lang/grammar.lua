#!/bin/sh -e
if true --[[; then
# vim: sw=4:noexpandtab
exec 3<"$0"
cd "${0%/*}/../../../build/$(uname -m)"
exec lua/src/lua - "$@" <<EOF
	local f,i,p,t = string.format, pairs, print, type
	local L, R = package.loadlib, package.preload
	local function r(o,e)
		if t(e) ~= "table" then p(f("%-24s%s", o, e))
		else for k,v in i(e) do r(f("%s[%s]", o, k), v) end end end
	R.lpeglabel = L("./loadall.so", "luaopen_lpeglabel")
	R.relabel   = L("./loadall.so", "luaopen_relabel")
	local m = loadfile('/dev/fd/3')()
	for _, chunk in ipairs(arg) do
		local program, msg, _, line, col = m.parse(chunk)
		if program then r("", program)
		else io.stderr:write("error: ", msg, " at line ", line or "?", " col ", col or "?", "\n") os.exit(1) end
	end
EOF
fi; --]] then

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
local sp = (blank^1)^-1
local eol = (P';' + nl)^1
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - nl)^0 * nl

local function awkregexunquote(s)
	return string.format("%q", s):gsub("\\\\", "\\"):gsub("\\/", "/")
end

local evalfmt = {
	-- TODO awk 'BEGIN { print 0.0=="0", ""=="" }' --> 1 1
	["=" ] = "%1 = ... return (...)",
	["?" ] = "and",
	[":" ] = "or",
	-- TODO awk 'BEGIN { print !"", !"0" }' --> 1 0
	["!" ] = "%1return ???",
	["&&"] = "and",
	["||"] = "or",
	[ "~"] = "return match(...)+0~=0",
	["!~"] = "return match(...)+0==0",
	-- TODO [1] vs. ["1"]
	["in"] = "(not %2[...])+0",
	-- ["*"] = "mul",
	-- ["%"] = "fmod",
	-- ["/"] = "div",
	-- ["//"] = "floordiv",
	-- ["^"]  = "pow",
}

local convfmt = {
	-- ["+" ] = "%2",
}

local function prepare(fmt, ...)
	local argt = {...}
	return fmt:gsub("%%(%d+)", function(i)
		return table.remove(argt, tonumber(i)) or ""
	end), table.concat(argt, ",")
end

local function eval(l, op, r)
	-- if evalfmt[op] then
	-- 	return string.format("eval(%q,%s)", prepare(evalfmt[op], l, r))
	-- elseif convfmt[op] then
	-- 	return prepare(convfmt[op], l, r)
	-- end
	return string.format("(%s%s%s)", l or "", op, r)
end

local function if_else(cond, stmt1, stmt2)
	print("IF_ELSE", cond, stmt1, stmt2)
end

local function while_do(cond, stmt)
	print("WHILE_DO", cond, stmt)
end

local function do_while(stmt, cond)
	print("DO_WHILE", stmt, cond)
end

local function for_in(var1, var2, stmt)
	print("FOR_IN", var1, var2, stmt)
end

local function generic_for(exp1, exp2, exp3, stmt)
	print("GENERIC_FOR", exp1, exp2, exp3, stmt)
end

local function delete(var, sub)
	print("DELETE", var, sub)
end

local function concat(...)
	return table.concat({...}, "..SUBSEP..")
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

	valuelist =
		  V'value' * (sp * P',' * sp * V'value')^0 * sp
		;

	-- TODO ++a--
	-- TODO ambiguous syntax: {}

	exp =
		--  P'++' * sp * Cs(V'tier14') / 'eval("%1=%1+1 return %1")' -- TODO ++a^1
		  V'lvalue' * S'^%*/+-'^-1 * P'=' * sp * V'tier13'
		+ V'tier13'
		;

	-- tier14 = Cf(C(V'lvalue') * Cg(C(S'^%*/+-'^-1 * P'=') * sp * V'tier13')^0, eval);
	-- ternary operator / conditional expression
	tier13 =
		  Cf(Cf(V'tier12' * Cg(Cs(P'?'/'&&') * sp * V'tier12'), eval) * sp * Cg(Cs(P':'/'||') * sp * V'tier12'), eval)
		+ V'tier12';
	tier12 = Cf(V'tier11' * Cg(C(P'||') * sp * V'tier11')^0, eval);
	tier11 = Cf(V'tier10' * Cg(C(P'&&') * sp * V'tier10')^0, eval);
	tier10 = Cf((P'(' * sp * V'arrayindex' * sp * P')' + V'tier09') * sp * Cg(C(P'in') * sp * V'tier09')^0, eval);
	tier09 = Cf(V'tier08' * Cg(C(P'!~' + P'~') * sp * (V'awkregex' + V'tier08'))^0, eval);
	tier08 = Cf(V'tier07' * Cg(C(S'<>!=' * P'=' + S'<>') * sp * V'tier07')^0, eval);
	-- TODO 'expr expr' (AWK, left-associative) 'expr .. expr' (Lua, right-associative)
	tier07 = Cf(V'tier06' * Cg(Cc('..') * sp * V'tier06')^0, eval);
	tier06 = Cf(V'tier05' * Cg(C(S'+-') * sp * V'tier05')^0, eval);
	tier05 = Cf(V'tier03' * Cg(C(P'//' + S'*/%') * sp * V'tier03')^0, eval);
	-- binary operators
	-- TODO !!a
	-- tier04 = Cf(Cc(nil) * Cg(C(S'!+-') * sp * V'tier04'), eval) + V'tier03';
	tier03 = Cf(Cs(V'value') * Cg(C(S'^') * sp * Cs(V'value'))^0, eval);

	-- tier02 = Cs((P'++' * sp * V'tier00') / 'eval("%1=%1+1 return %1")') + V'tier00';
	-- tier01 = Cf(Cs(V'tier00') * Cg(C(S'^') * sp * Cs(V'tier00'))^0, eval);
	-- tier00 = Cg(Cs(V'value') * sp * (C(S'-=' * P'>') * sp * Cs(V'value'))^0);

	value =
		  V'awkfieldref'
		+ V'lvalue' + P'(' * sp * V'explist'^0 * sp * P')'
		+ V'simple'
		;

	lvalue =
		  V'name' * (sp * V'subscript')^-1
		+ V'awkfieldref'
		;

	subscript =
		  P'[' * sp * V'arrayindex' * sp * P']'
		;

	arrayindex =
		  (Cs(V'exp') * (sp * P',' * sp * Cs(V'exp'))^0) / concat
		;

	simple =
		  locale.digit * locale.alnum^0
		+ V'string'
		+ V'name'
		;

	chunk =
		  (V'stmt' + eol + blank^1)^0
		-- + P'{' * sp * Cs(V'chunk') * sp * P'}'
		;

	simple_stmt =
		  P'delete' * noident * sp * C(V'name') * (P'[' * sp * Cs(V'arrayindex') * sp * P']')^-1
		  / delete
		+ P'print' * noident * sp * P'(' * sp * V'explist'^0 * sp * P')'
		+ P'print' * noident * Cc'(' * sp * V'explist'^0 * Cc')'
		+ V'exp'
		;

	stmt =
		  P'if' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')' * sp * Cs(V'stmt') * sp *
		  (P'else' * noident * sp * Cs(V'stmt'))^-1
		  / if_else
		+ P'while' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')' * sp * Cs(V'stmt')
		  / while_do
		+ P'do' * noident * sp * Cs(V'stmt') * sp * P'while' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')'
		  / do_while
		+ P'for' * noident * sp * P'(' * C(V'name') * sp *
		  P'in' * noident * sp * C(V'name') * P')' * sp * Cs(V'stmt')
		  / for_in
		+ P'for' * noident * sp * P'(' * sp *
		  Cs(V'simple_stmt') * sp * P';' * sp *
		  Cs(V'exp') * sp * P';' * sp *
		  Cs(V'simple_stmt') * sp * P')' * sp * Cs(V'stmt')
		  / generic_for
		+ V'simple_stmt'
		+ V'action'
		+ eol
		;

	["function"] =
		  P'function' * noident * blank^1 * V'name' * sp * '(' * sp * V'explist'^0 * sp * ')' * sp
		* '{' * sp * V'chunk' * sp * '}'
		;

	keyword =
		  V'awkkeywords'
		;

	luakeywords =
		  P'elseif' * noident
		+ P'end' * noident
		+ P'false' * noident
		+ P'goto' * noident
		+ P'local' * noident
		+ P'nil' * noident
		+ P'repeat' * noident
		+ P'then' * noident
		+ P'true' * noident
		+ P'until' * noident
		;

	awkkeywords =
		  P'break' * noident
		+ P'continue' * noident
		+ P'delete' * noident
		+ P'do' * noident
		+ P'else' * noident
		+ P'for' * noident
		+ P'function' * noident
		+ P'if' * noident
		+ P'in' * noident
		+ P'retur( ((_ENV)[((2+2))]*3))n' * noident
		+ P'while' * noident
		+ P'BEGIN' * noident
		+ P'END' * noident
		+ P'BEGINFILE' * noident
		+ P'ENDFILE' * noident
		+ V'awkbuiltins'
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
		  P'$' * sp * Cs(V'value') / '(_ENV)[%1]'
		;

	awkregex =
		  '/' * Cs((P'\\' * P(1) + (1 - P'/'))^0) * '/' / awkregexunquote
		;

	name =
		  (locale.alpha + '_') * (locale.alnum + '_')^0 - V'keyword'
		;

	string =
		  P'"' * ('\\' * P(1) + (P(1) - '"'))^0 * P'"'
		+ P"'" * ("\\" * P(1) + (P(1) - "'"))^0 * P"'"
		+ V'awkregex' / 'match(_ENV[0],%1)'
		;

	comment =
		  '#' * (P(1) - nl)^0 * (nl + -P(1)) / '\n'
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

return M end
