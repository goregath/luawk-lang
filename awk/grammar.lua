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

local space = (locale.space + V'comment')^0
local newline = P'\n'
local noident = -(locale.alnum + P'_')

local Kand = P('and') * noident
local Kbreak = P('break') * noident
local Kdo = P('do') * noident
local Kelse = P('else') * noident
local Kelseif = P('elseif') * noident
local Kend = P('end') * noident
local Kfalse = P('false') * noident
local Kfor = P('for') * noident
local Kfunction = P('function') * noident
local Kif = P('if') * noident
local Kin = P('in') * noident
local Klocal = P('local') * noident
local Knil = P('nil') * noident
local Knot = P('not') * noident
local Kor = P('or') * noident
local Krepeat = P('repeat') * noident
local Kreturn = P('return') * noident
local Kthen = P('then') * noident
local Ktrue = P('true') * noident
local Kuntil = P('until') * noident
local Kwhile = P('while') * noident

local Kgetline = P('getline') * noident
local Kprint = P('print') * noident
local Kprintf = P('printf') * noident
local Knext = P('next') * noident
local Knextfile = P('nextfile') * noident
local Kexit = P('exit') * noident

local shebang = P"#" * (P(1) - newline)^0 * newline;

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

	shebang^-1 * V'newobj' * ((space * (V'awkenv' + V'awkrule') * (space * P';')^-1)^1)^0 * space * -1;

	-- AWK language extensions

	awkenv =
		  Cb('program') * Cc('BEGIN') / rawget * V'awkfunction' / table.insert
		;
	awkrule =
		  Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * space * V'awkaction') / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * Cc('print()')) / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(Cc(true) * V'awkaction') / table.insert
		+ Cb('program') * C(V'awkspecialpattern') / rawget * space * V'awkaction' / table.insert
		;
	awkpatternlist =
		  -P'{' * Cg(Cs(V'awkpattern') * (space * P',' * space * Cs(V'awkpattern'))^-1)
		;
	awkspecialpattern =
		  P'BEGINFILE' + P'ENDFILE' + P'BEGIN' + P'END'
		;
	awkpattern =
		  -(V'awkspecialpattern') * V'exp'
		;
	awkaction =
		  P'{' * space * Cs(V'chunk') * space * P'}'
		;
	awkfunction =
		Cg(Klocal^-1 * space * Kfunction * space * V'Name' * space *
			P"(" * space * (V'parlist' * space)^-1 * P")" * space) * Cg(
				-- (P'{' * space * Cs(V'block') * space * P'}') / '%1 end' +
				((V'block') * space * Kend)
		) / '%1%2';
	awkrecord =
		  (P'$' * space * Cs(V'Number' + V'var')) / 'F[%1]'
		+ (P'$' * space * Cs(V'exp')) / 'F[%1]'
		;
	awkregex =
		  P'/' * Cg((P"\\" * P(1) + (1 - P"/"))^0) * P'/' / quote
		;
	awkmatchexp =
		  Cf(Cs(V'value') * (space * Ct(Cg(P'!~' + P'~') * space * Cs(V'awkregex' + V'value')))^1, function(a,c)
			return string.format("%smatch(%s,%s)", c[1]=='!~' and 'not ' or '', a, c[2])
		  end)
		;

	-- keywords

	keywords =
		  Kand
		+ Kbreak
		+ Kdo
		+ Kelse
		+ Kelseif
		+ Kend
		+ Kfalse
		+ Kfor
		+ Kfunction
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

	-- longstrings

	longstring = C(P{ -- from Roberto Ierusalimschy's lpeg examples
		V'open' * C((P(1) - V'closeeq')^0) * V'close' / function (o, s) return s end;
		open =
			  "[" * Cg((P"=")^0, "init") * P"[" * (newline)^-1
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
		+ P"--" * (P(1) - newline)^0 * (newline + -P(1))
		;
	-- ["⌴"] =
	-- 	  (locale.space + V'comment')^0
	-- 	;

	-- Types and Comments

	Name =
		  (locale.alpha + P'_') * (locale.alnum + P'_')^0 - V'keywords'
		+ V'awkrecord'
		;
	Number =
		  (P"-")^-1 * space * P'0x' * locale.xdigit^1 * -(locale.alnum + P'_')
		+ (P"-")^-1 * space * locale.digit^1 * (P"." * locale.digit^1)^-1 * (S "eE" * (P"-")^-1 * locale.digit^1)^-1 * -(locale.alnum + P'_')
		+ (P"-")^-1 * space * P"." * locale.digit^1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + P'_')
		;
	String =
		  P"\"" * (P"\\" * P(1) + (1 - P"\""))^0 * P"\""
		+ P"'" * (P"\\" * P(1) + (1 - P"'"))^0 * P"'"
		+ V'longstring'
		;

	-- Lua Complete Syntax

	chunk =
		  (space * V'stat' * (space * P";")^-1)^0 * (space * V'laststat' * (space * P";")^-1)^-1
		;

	block = V'chunk';

	stat =
		  Kdo * space * V'block' * space * Kend
		+ Kwhile * space * V'exp' * space * Kdo * space * V'block' * space * Kend
		+ Krepeat * space * V'block' * space * Kuntil * space * V'exp'
		+ Kif * space * V'exp' * space * Kthen * space * V'block' * space *
			(Kelseif * space * V'exp' * space * Kthen * space * V'block' * space)^0 *
			(Kelse * space * V'block' * space)^-1 * Kend
		+ Kfor * space * V'Name' * space * P"=" * space *
			V'exp' * space * P"," * space * V'exp' * (space * P"," * space * V'exp')^-1 * space *
			Kdo * space * V'block' * space * Kend
		+ Kfor * space * V'namelist' * space * Kin * space * V'explist' * space * Kdo * space * V'block' * space * Kend
		+ Kfunction * space * V'funcname' * space *  V'funcbody'
		+ Klocal * space * Kfunction * space * V'Name' * space * V'funcbody'
		 -- local name [+-*/%^]= exp
		+ (Klocal * space * Cs(V'Name') * space * Cs(S'+-*/%^') * P"=" * space * Cs(V'exp')) / 'local %1=%1%2(%3)'
		+ Klocal * space * V'namelist' * (space * P"=" * space * V'explist')^-1
		+ V'varlist' * space * P"=" * space * V'explist'
		-- var [+-*/%^]= exp
		+ (Cs(V'var') * space * Cs(S'+-*/%^') * P"=" * space * Cs(V'exp')) / '%1=%1%2(%3)'
		+ V'functioncall'
		+ V'awkexit'
		+ V'awktoken'
		+ V'awknext'
		;
	awknext =
		  (Knext + Knextfile) / 'coroutine.yield("%0")'
		;
	awkexit =
		  Cs((Kexit) / '"%0"' * (space * Cc',' * V'exp')^-1) / 'coroutine.yield(%1)'
		;
	awktoken =
		  Cs(V'awkkeywords' * Cc('(') * (space * V'explist')^-1 * Cc(')'))
		;
	awkkeywords =
		  Kprintf + Kprint + Kgetline
		;
	laststat =
		  Kreturn * (space * V'explist')^-1 + Kbreak
		;
	funcname =
		  V'Name' * (space * P"." * space * V'Name')^0 * (space * P":" * space * V'Name')^-1
		;
	namelist =
		  V'Name' * (space * P"," * space * V'Name')^0
		;
	varlist =
		  V'var' * (space * P"," * space * V'var')^0
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
		  Knil
		+ Kfalse
		+ Ktrue
		+ V'Number'
		+ V'String'
		+ P"..."
		+ Cs(V'awkregex') / 'match(F[0],%1)'
		+ V'function'
		+ V'tableconstructor'
		+ V'functioncall'
		+ V'var'
		+ P"(" * space * V'exp' * space * P")"
		;
	-- An expression operates on values to produce a new value or is a value
	exp =
		  V'unop' * space * V'exp'
		+ V'awkmatchexp' * (space * V'binop' * space * V'exp')^-1
		+ V'value' * (space * V'binop' * space * V'exp')^-1
		;
	-- Index and Call
	index =
		  P"[" * space * V'exp' * space * P"]"
		+ P"." * space * V'Name'
		;
	call =
		  V'args'
		+ P":" * space * V'Name' * space * V'args'
		;
	-- A Prefix is a the leftmost side of a var(iable) or functioncall
	prefix =
		  P"(" * space * V'exp' * space * P")" + V'Name'
		;
	-- A Suffix is a Call or Index
	suffix =
		  V'call' + V'index'
		;
	var =
		  V'prefix' * (space * V'suffix' * #(space * V'suffix'))^0 * space * V'index' + V'Name'
		;
	functioncall =
		  V'prefix' * (space * V'suffix' * #(space * V'suffix'))^0 * space * V'call'
		;
	explist =
		  V'exp' * (space * P"," * space * V'exp')^0
		;
	-- args = P"(" * space * (V'explist' * space)^-1 * P")" +
	-- V'tableconstructor' +
	-- V'String';
	args =
		  P"(" * space * (V'explist' * space)^-1 * P")"
		;
	["function"] =
		  Kfunction * space * V'funcbody'
		;
	funcbody =
		  P"(" * space * (V'parlist' * space)^-1 * P")" * space *  V'block' * space * Kend
		;
	parlist =
		  V'namelist' * (space * P"," * space * P"...")^-1 + P"..."
		;
	tableconstructor =
		  P"{" * space * (V'fieldlist' * space)^-1 * P"}"
		;
	fieldlist =
		  V'field' * (space * V'fieldsep' * space * V'field')^0 * (space * V'fieldsep')^-1
		;
	field =
		  P"[" * space * V'exp' * space * P"]" * space * P"=" * space * V'exp'
		+ V'Name' * space * P"=" * space * V'exp'
		+ V'exp'
		;
	fieldsep =
		  P","
		+ P";"
		;
	binop = -- match longest token sequences first
		  Kand
		+ Kor
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
		+ Knot
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