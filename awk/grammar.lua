#!/usr/bin/env lua

--- Luawk parser.
-- @alias M
-- @module grammar

local M = {}

local lpeg = require 'lpeglabel'
local re = require 'relabel'
local locale = lpeg.locale();

local P, S, V = lpeg.P, lpeg.S, lpeg.V;

local C, Cb, Cc, Cf, Cg, Cs, Ct, Cmt =
lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Cs, lpeg.Ct, lpeg.Cmt;

local shebang = P"#" * (P(1) - P"\n")^0 * P"\n";

local function K(k) -- keyword
	return P(k) * -(locale.alnum + P'_');
end

local function quote(s)
	return string.format("%q", s)
end

--- Lua AWK grammar and parser.
-- Based on Patrick Donnelly LPeg recipe:
-- http://lua-users.org/wiki/LpegRecipes
-- @author Patrick Donnelly (https://github.com/batrick)
local grammar = {
	-- TODO pattern: support re-pattern /.../, `exp` ~ /.../ and `exp` !~ /.../
	-- TODO support ! expr
	-- TODO support expr in array
	-- TODO support (index) in array
	-- TODO support expr1 ? expr2 : expr3
	-- TODO support expr expr (string concatenation)
	-- TODO support for-loop
	-- TODO support lvalue++, ++lvalue
	-- TODO support autoinit of variables
	-- TODO support field access $`Number` and $(`exp`)
	-- TODO support builtin functions w/o parenthesis
	-- TODO unary_expr: unary_expr '?' expr ':' expr
	-- TODO unary_expr: unary_expr In NAME
	-- TODO non_unary_expr: '!' expr
	-- TODO non_unary_expr: '+' expr
	-- TODO non_unary_expr: lvalue INCR
	-- TODO non_unary_expr: lvalue DECR
	-- TODO non_unary_expr: INCR lvalue
	-- TODO non_unary_expr: DECR lvalue
	-- TEST awk '$0 ~ /b/ ~ 1 { print }' <<<"a b c" --> "a b c"

	-- Tokens:
	-- -------
	-- BEGIN, break, continue, delete, do
	-- else, END, exit, for, function,
	-- getline, if, in, next, print,
	-- printf, return, while

	-- AWK grammar

	newobj = Cg(Cc({
		BEGIN = {},
		END = {},
		BEGINFILE = {},
		ENDFILE = {},
		main = {}
	}), 'program');

	shebang^-1 * V'newobj' * ((V'⌴' * (V'awkenv' + V'awkrule') * (V'⌴' * P';')^-1)^1)^0 * V'⌴' * -1;

	-- AWK language extensions

	awkenv =
		  Cb('program') * Cc('BEGIN') / rawget * V'awkfunction' / table.insert
		;
	awkrule =
		  Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * V'⌴' * V'awkaction') / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * Cc('print()')) / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(Cc(true) * V'awkaction') / table.insert
		+ Cb('program') * C(V'awkspecialpattern') / rawget * V'⌴' * V'awkaction' / table.insert
		;
	awkpatternlist =
		  -P'{' * Cg(Cs(V'awkpattern') * (V'⌴' * P',' * V'⌴' * Cs(V'awkpattern'))^-1)
		;
	awkspecialpattern =
		  P'BEGINFILE' + P'ENDFILE' + P'BEGIN' + P'END'
		;
	awkpattern =
		  -(V'awkspecialpattern') * V'exp'
		;
	awkaction =
		  P'{' * V'⌴' * Cs(V'chunk') * V'⌴' * P'}'
		;
	awkfunction =
		Cg(K'local'^-1 * V'⌴' * K'function' * V'⌴' * V'Name' * V'⌴' *
			P"(" * V'⌴' * (V'parlist' * V'⌴')^-1 * P")" * V'⌴') * Cg(
				-- (P'{' * V'⌴' * Cs(V'block') * V'⌴' * P'}') / '%1 end' +
				((V'block') * V'⌴' * K'end')
		) / '%1%2';
	awkrecord =
		  (P'$' * V'⌴' * Cs(V'Number' + V'var')) / 'F[%1]'
		+ (P'$' * V'⌴' * Cs(V'exp')) / 'F[%1]'
		;
	awkregex =
		  P'/' * Cg((P"\\" * P(1) + (1 - P"/"))^0) * P'/' / quote
		;
	awkmatchexp =
		  Cf(Cs(V'value') * (V'⌴' * Ct(Cg(P'!~' + P'~') * V'⌴' * Cs(V'awkregex' + V'value')))^1, function(a,c)
			return string.format("%smatch(%s,%s)", c[1]=='!~' and 'not ' or '', a, c[2])
		  end)
		;

	-- keywords

	keywords =
		  K'and'
		+ K'break'
		+ K'do'
		+ K'else'
		+ K'elseif'
		+ K'end'
		+ K'false'
		+ K'for'
		+ K'function'
		+ K'if'
		+ K'in'
		+ K'local'
		+ K'nil'
		+ K'not'
		+ K'or'
		+ K'repeat'
		+ K'return'
		+ K'then'
		+ K'true'
		+ K'until'
		+ K'while'
		;

	-- longstrings

	longstring = C(P{ -- from Roberto Ierusalimschy's lpeg examples
		V'open' * C((P(1) - V'closeeq')^0) * V'close' / function (o, s) return s end;
		open =
			  "[" * Cg((P"=")^0, "init") * P"[" * (P"\n")^-1
			;
		close =
			  "]" * C((P"=")^0) * "]"
			;
		closeeq =
			  Cmt(V'close' * Cb "init", function (s, i, a, b) return a == b end)
	});

	-- comments & whitespace

	comment =
		  P"--" * V'longstring'
		+ P"--" * (P(1) - P"\n")^0 * (P"\n" + -P(1))
		;
	["⌴"] =
		  (locale.space + V'comment')^0
		;

	-- Types and Comments

	Name =
		  (locale.alpha + P'_') * (locale.alnum + P'_')^0 - V'keywords'
		+ V'awkrecord'
		;
	Number =
		  (P"-")^-1 * V'⌴' * P'0x' * locale.xdigit^1 * -(locale.alnum + P'_')
		+ (P"-")^-1 * V'⌴' * locale.digit^1 * (P"." * locale.digit^1)^-1 * (S "eE" * (P"-")^-1 * locale.digit^1)^-1 * -(locale.alnum + P'_')
		+ (P"-")^-1 * V'⌴' * P"." * locale.digit^1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + P'_')
		;
	String =
		  P"\"" * (P"\\" * P(1) + (1 - P"\""))^0 * P"\""
		+ P"'" * (P"\\" * P(1) + (1 - P"'"))^0 * P"'"
		+ V'longstring'
		;

	-- Lua Complete Syntax

	chunk =
		  (V'⌴' * V'stat' * (V'⌴' * P";")^-1)^0 * (V'⌴' * V'laststat' * (V'⌴' * P";")^-1)^-1
		;

	block = V'chunk';

	stat =
		  K'do' * V'⌴' * V'block' * V'⌴' * K'end'
		+ K'while' * V'⌴' * V'exp' * V'⌴' * K'do' * V'⌴' * V'block' * V'⌴' * K'end'
		+ K'repeat' * V'⌴' * V'block' * V'⌴' * K'until' * V'⌴' * V'exp'
		+ K'if' * V'⌴' * V'exp' * V'⌴' * K'then' * V'⌴' * V'block' * V'⌴' *
			(K'elseif' * V'⌴' * V'exp' * V'⌴' * K'then' * V'⌴' * V'block' * V'⌴')^0 *
			(K'else' * V'⌴' * V'block' * V'⌴')^-1 * K'end'
		+ K'for' * V'⌴' * V'Name' * V'⌴' * P"=" * V'⌴' *
			V'exp' * V'⌴' * P"," * V'⌴' * V'exp' * (V'⌴' * P"," * V'⌴' * V'exp')^-1 * V'⌴' *
			K'do' * V'⌴' * V'block' * V'⌴' * K'end'
		+ K'for' * V'⌴' * V'namelist' * V'⌴' * K'in' * V'⌴' * V'explist' * V'⌴' * K'do' * V'⌴' * V'block' * V'⌴' * K'end'
		+ K'function' * V'⌴' * V'funcname' * V'⌴' *  V'funcbody'
		+ K'local' * V'⌴' * K'function' * V'⌴' * V'Name' * V'⌴' * V'funcbody'
		 -- local name [+-*/%^]= exp
		+ (K'local' * V'⌴' * Cs(V'Name') * V'⌴' * Cs(S'+-*/%^') * P"=" * V'⌴' * Cs(V'exp')) / 'local %1=%1%2(%3)'
		+ K'local' * V'⌴' * V'namelist' * (V'⌴' * P"=" * V'⌴' * V'explist')^-1
		+ V'varlist' * V'⌴' * P"=" * V'⌴' * V'explist'
		-- var [+-*/%^]= exp
		+ (Cs(V'var') * V'⌴' * Cs(S'+-*/%^') * P"=" * V'⌴' * Cs(V'exp')) / '%1=%1%2(%3)'
		+ V'functioncall'
		+ V'awkexit'
		+ V'awktoken'
		+ V'awknext'
		;
	awknext =
		  (K'next' + K'nextfile') / 'coroutine.yield("%0")'
		;
	awkexit =
		  Cs((K'exit') / '"%0"' * (V'⌴' * Cc',' * V'exp')^-1) / 'coroutine.yield(%1)'
		;
	awktoken =
		  Cs(V'awkkeywords' * Cc('(') * (V'⌴' * V'explist')^-1 * Cc(')'))
		;
	awkkeywords =
		  K'printf' + K'print' + K'getline'
		;
	laststat =
		  K'return' * (V'⌴' * V'explist')^-1 + K'break'
		;
	funcname =
		  V'Name' * (V'⌴' * P"." * V'⌴' * V'Name')^0 * (V'⌴' * P":" * V'⌴' * V'Name')^-1
		;
	namelist =
		  V'Name' * (V'⌴' * P"," * V'⌴' * V'Name')^0
		;
	varlist =
		  V'var' * (V'⌴' * P"," * V'⌴' * V'var')^0
		;

	-- Let's come up with a syntax that does not use left recursion
	-- (only listing changes to Lua 5.1 extended BNF syntax)
	-- value ::= nil | false | true | Number | String | '...' | function |
	--           tableconstructor | functioncall | var | '(' exp ')'
	-- exp ::= unop exp | value [binop exp]
	-- prefix ::= '(' exp ')' | Name
	-- index ::= '[' exp ']' | '.' Name
	-- call ::= args | ':' Name args
	-- suffix ::= call | index
	-- var ::= prefix {suffix} index | Name
	-- functioncall ::= prefix {suffix} call

	-- Something that represents a value (or many values)
	value =
		  K'nil'
		+ K'false'
		+ K'true'
		+ V'Number'
		+ V'String'
		+ P"..."
		+ Cs(V'awkregex') / 'match(F[0],%1)'
		+ V'function'
		+ V'tableconstructor'
		+ V'functioncall'
		+ V'var'
		+ P"(" * V'⌴' * V'exp' * V'⌴' * P")"
		;
	-- An expression operates on values to produce a new value or is a value
	exp =
		  V'unop' * V'⌴' * V'exp'
		+ V'awkmatchexp' * (V'⌴' * V'binop' * V'⌴' * V'exp')^-1
		+ V'value' * (V'⌴' * V'binop' * V'⌴' * V'exp')^-1
		;
	-- Index and Call
	index =
		  P"[" * V'⌴' * V'exp' * V'⌴' * P"]"
		+ P"." * V'⌴' * V'Name'
		;
	call =
		  V'args'
		+ P":" * V'⌴' * V'Name' * V'⌴' * V'args'
		;
	-- A Prefix is a the leftmost side of a var(iable) or functioncall
	prefix =
		  P"(" * V'⌴' * V'exp' * V'⌴' * P")" + V'Name'
		;
	-- A Suffix is a Call or Index
	suffix =
		  V'call' + V'index'
		;
	var =
		  V'prefix' * (V'⌴' * V'suffix' * #(V'⌴' * V'suffix'))^0 * V'⌴' * V'index' + V'Name'
		;
	functioncall =
		  V'prefix' * (V'⌴' * V'suffix' * #(V'⌴' * V'suffix'))^0 * V'⌴' * V'call'
		;
	explist =
		  V'exp' * (V'⌴' * P"," * V'⌴' * V'exp')^0
		;
	-- args = P"(" * V'⌴' * (V'explist' * V'⌴')^-1 * P")" +
	-- V'tableconstructor' +
	-- V'String';
	args =
		  P"(" * V'⌴' * (V'explist' * V'⌴')^-1 * P")"
		;
	["function"] =
		  K'function' * V'⌴' * V'funcbody'
		;
	funcbody =
		  P"(" * V'⌴' * (V'parlist' * V'⌴')^-1 * P")" * V'⌴' *  V'block' * V'⌴' * K'end'
		;
	parlist =
		  V'namelist' * (V'⌴' * P"," * V'⌴' * P"...")^-1 + P"..."
		;
	tableconstructor =
		  P"{" * V'⌴' * (V'fieldlist' * V'⌴')^-1 * P"}"
		;
	fieldlist =
		  V'field' * (V'⌴' * V'fieldsep' * V'⌴' * V'field')^0 * (V'⌴' * V'fieldsep')^-1
		;
	field =
		  P"[" * V'⌴' * V'exp' * V'⌴' * P"]" * V'⌴' * P"=" * V'⌴' * V'exp'
		+ V'Name' * V'⌴' * P"=" * V'⌴' * V'exp'
		+ V'exp'
		;
	fieldsep =
		  P","
		+ P";"
		;
	binop = -- match longest token sequences first
		  K'and'
		+ K'or'
		+ P'..'
		+ P'<='
		+ P'>='
		+ P'=='
		+ P'~='
		+ P'&&' / ' and '
		+ P'||' / ' or '
		+ P'!=' / ' ~= '
		+ P'+'
		+ P'-'
		+ P'*'
		+ P'/'
		+ P'^'
		+ P'%'
		+ P'<'
		+ P'>'
		;
	unop =
		  P"-"
		+ P"#"
		+ P'!' / 'not '
		+ K'not'
		;
};

--- Parse luawk source string.
--  @param[type=string]  source input string
--  @return[1] table
--  @return[2,type=nil]    generic error
--  @return[2,type=string] error message
--  @return[3,type=false]  parser error
--  @return[3,type=string] error message
--  @return[3,type=number] position in source
--  @return[3,type=number] source line
--  @return[3,type=number] source column
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

if (...) ~= "awk.grammar" then
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