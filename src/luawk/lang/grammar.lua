#!/usr/bin/env lua

--- Luawk parser based on an Lua 5.1 grammer, written in LPeg by Patrick
--  Donnelly (https://github.com/batrick).
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

local sp = (locale.space + V'comment')^0
local newline = P'\n'
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - newline)^0 * newline

local Kand = P'and' * noident
local Kbreak = P'break' * noident
local Kdo = P'do' * noident
local Kelse = P'else' * noident
local Kelseif = P'elseif' * noident
local Kend = P'end' * noident
local Kfalse = P'false' * noident
local Kfor = P'for' * noident
local Kfunction = P'function' * noident
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

local Kexit = 'exit' * noident
local Kgetline = 'getline' * noident
local Knext = 'next' * noident
local Knextfile = 'nextfile' * noident
local Kprint = 'print' * noident
local Kprintf = 'printf' * noident

-- AWK builtin functions
local Katan2 = P'atan2' * noident
local Kclose = P'close' * noident
local Kcos = P'cos' * noident
local Kexp = P'exp' * noident
local Kgsub = P'gsub' * noident
local Kindex = P'index' * noident
local Kint = P'int' * noident
local Klength = P'length' * noident
local Klog = P'log' * noident
local Kmatch = P'match' * noident
local Krand = P'rand' * noident
local Ksin = P'sin' * noident
local Ksplit = P'split' * noident
local Ksprintf = P'sprintf' * noident
local Ksqrt = P'sqrt' * noident
local Ksrand = P'srand' * noident
local Ksub = P'sub' * noident
local Ksubstr = P'substr' * noident
local Ksystem = P'system' * noident
local Ktolower = P'tolower' * noident
local Ktoupper = P'toupper' * noident

-- GNU AWK builtin functions
local Kpatsplit = P'patsplit' * noident

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

	newobj = Cg(Cc({
		BEGIN = {},
		END = {},
		BEGINFILE = {},
		ENDFILE = {},
		main = {}
	}), 'program');

	shebang^-1 * V'newobj' * ((sp * (V'awkenv' + V'awkrule') * (sp * ';')^-1)^1)^0 * sp * -1;

	-- AWK language extensions

	awkenv =
		  Cb('program') * Cc('BEGIN') / rawget * V'awkfunction' / table.insert
		;
	awkrule =
		  Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * sp * V'awkaction') / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(V'awkpatternlist' * Cc('print()')) / table.insert
		+ Cb('program') * Cc('main') / rawget * Ct(Cc(true) * V'awkaction') / table.insert
		+ Cb('program') * C(V'awkspecialpattern') / rawget * sp * V'awkaction' / table.insert
		;
	awkpatternlist =
		  -P'{' * Cg(Cs(V'awkpattern') * (sp * ',' * sp * Cs(V'awkpattern'))^-1)
		;
	awkspecialpattern =
		  P'BEGINFILE' + 'ENDFILE' + 'BEGIN' + 'END'
		;
	awkpattern =
		  -(V'awkspecialpattern') * V'exp'
		;
	awkaction =
		  '{' * sp * Cs(V'chunk') * sp * '}'
		;
	awkfunction =
		Cg(Klocal^-1 * sp * Kfunction * sp * V'Name' * sp *
			'(' * sp * (V'parlist' * sp)^-1 * ')' * sp) * Cg(
				((V'block') * sp * Kend)
		) / '%1%2';
	awkrecord =
		  ('$' * sp * Cs(V'Number' + V'var')) / '_ENV[%1]'
		+ ('$' * sp * Cs(V'exp')) / '_ENV[%1]'
		;
	awkregex =
		  '/' * Cg((P'\\' * P(1) + (1 - P'/'))^0) * '/' / quote
		;
	awkmatchexp =
		  Cf(Cs(V'value') * (sp * Ct(Cg(P'!~' + P'~') * sp * Cs(V'awkregex' + V'value')))^1, function(a,c)
			return string.format("%smatch(%s,%s)", c[1]=='!~' and 'not ' or '', a, c[2])
		  end)
		;
	awknext =
		  (Knext + Knextfile) / 'coroutine.yield("%0")'
		;
	awkexit =
		  Cs(Kexit / '"%0"' * (sp * Cc',' * V'exp')^-1) / 'coroutine.yield(%1)'
		;
	awktoken =
		  Cs(V'awkkeywords' * Cc'(' * (sp * V'explist')^-1 * Cc')')
		;
	awkkeywords =
		  Kprintf
		+ Kprint
		+ Kgetline
		;
	awkbuiltins =
		  Katan2
		+ Kclose
		+ Kcos
		+ Kexp
		+ Kgsub
		+ Kindex
		+ Kint
		+ Klength
		+ Klog
		+ Kmatch
		+ Kpatsplit
		+ Krand
		+ Ksin
		+ Ksplit
		+ Ksprintf
		+ Ksqrt
		+ Ksrand
		+ Ksub
		+ Ksubstr
		+ Ksystem
		+ Ktolower
		+ Ktoupper
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
			  '[' * Cg((P'=')^0, "init") * '[' * (newline)^-1
			;
		close =
			  ']' * C((P'=')^0) * ']'
			;
		closeeq =
			  Cmt(V'close' * Cb'init', function (s, i, a, b) return a == b end)
	});

	-- comments & whitespace

	comment =
		  '--' * V'longstring'
		+ '--' * (P(1) - newline)^0 * (newline + -P(1))
		;

	-- Types and Comments

	Name =
		  (locale.alpha + '_') * (locale.alnum + '_')^0 - V'keywords'
		+ V'awkrecord'
		;
	Number =
		  (P'-')^-1 * sp * '0x' * locale.xdigit^1 * -(locale.alnum + '_')
		+ (P'-')^-1 * sp * locale.digit^1 * ('.' * locale.digit^1)^-1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + '_')
		+ (P'-')^-1 * sp * '.' * locale.digit^1 * (S'eE' * (P'-')^-1 * locale.digit^1)^-1 * -(locale.alnum + '_')
		;
	String =
		  '"' * ('\\' * P(1) + (P(1) - '"'))^0 * '"'
		+ "'" * ("\\" * P(1) + (P(1) - "'"))^0 * "'"
		+ V'longstring'
		;

	-- Lua Complete Syntax

	chunk =
		  (sp * V'stat' * (sp * ';')^-1)^0 * (sp * V'laststat' * (sp * ';')^-1)^-1
		;

	block = V'chunk';

	stat =
		  Kdo * sp * V'block' * sp * Kend
		+ Kwhile * sp * V'exp' * sp * Kdo * sp * V'block' * sp * Kend
		+ Krepeat * sp * V'block' * sp * Kuntil * sp * V'exp'
		+ Kif * sp * V'exp' * sp * Kthen * sp * V'block' * sp *
			(Kelseif * sp * V'exp' * sp * Kthen * sp * V'block' * sp)^0 *
			(Kelse * sp * V'block' * sp)^-1 * Kend
		+ Kfor * sp * V'Name' * sp * '=' * sp *
			V'exp' * sp * ',' * sp * V'exp' * (sp * ',' * sp * V'exp')^-1 * sp *
			Kdo * sp * V'block' * sp * Kend
		+ Kfor * sp * V'namelist' * sp * Kin * sp * V'explist' * sp * Kdo * sp * V'block' * sp * Kend
		+ Kfunction * sp * V'funcname' * sp *  V'funcbody'
		+ Klocal * sp * Kfunction * sp * V'Name' * sp * V'funcbody'
		 -- local name [+-*/%^]= exp
		+ (Klocal * sp * Cs(V'Name') * sp * Cs(S'+-*/%^') * '=' * sp * Cs(V'exp')) / 'local %1=%1%2(%3)'
		+ Klocal * sp * V'namelist' * (sp * '=' * sp * V'explist')^-1
		+ V'varlist' * sp * '=' * sp * V'explist'
		-- var [+-*/%^]= exp
		+ (Cs(V'var') * sp * Cs(S'+-*/%^') * '=' * sp * Cs(V'exp')) / '%1=%1%2(%3)'
		+ V'functioncall'
		+ V'awkexit'
		+ V'awktoken'
		+ V'awknext'
		;
	laststat =
		  Kreturn * (sp * V'explist')^-1 + Kbreak
		;
	funcname =
		  V'Name' * (sp * '.' * sp * V'Name')^0 * (sp * ':' * sp * V'Name')^-1
		;
	namelist =
		  V'Name' * (sp * ',' * sp * V'Name')^0
		;
	varlist =
		  V'var' * (sp * ',' * sp * V'var')^0
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
		+ '...'
		+ Cs(V'awkregex') / 'match(_ENV[0],%1)'
		+ V'function'
		+ V'tableconstructor'
		+ V'functioncall'
		+ V'var'
		+ '(' * sp * V'exp' * sp * ')'
		;
	-- An expression operates on values to produce a new value or is a value
	exp =
		  V'unop' * sp * V'exp'
		+ V'awkmatchexp' * (sp * V'binop' * sp * V'exp')^-1
		+ V'value' * (sp * V'binop' * sp * V'exp')^-1
		;
	-- Index and Call
	index =
		  '[' * sp * V'exp' * sp * ']'
		+ '.' * sp * V'Name'
		;
	call =
		  V'args'
		+ ':' * sp * V'Name' * sp * V'args'
		;
	-- A Prefix is a the leftmost side of a var(iable) or functioncall
	prefix =
		  '(' * sp * V'exp' * sp * ')' + V'Name'
		;
	-- A Suffix is a Call or Index
	suffix =
		  V'call' + V'index'
		;
	var =
		  V'prefix' * (sp * V'suffix' * #(sp * V'suffix'))^0 * sp * V'index' + V'Name'
		;
	functioncall =
		  V'prefix' * (sp * V'suffix' * #(sp * V'suffix'))^0 * sp * V'call'
		;
	explist =
		  V'exp' * (sp * ',' * sp * V'exp')^0
		;
	-- args =
	-- '(' * sp * (V'explist' * sp)^-1 * ')'
	-- + (#Cb("action") * V'String')
	-- + (#Cb("action") * V'tableconstructor')
	-- ;
	args =
		  P'(' * sp * (V'explist' * sp)^-1 * P')'
		;
	["function"] =
		  Kfunction * sp * V'funcbody'
		;
	funcbody =
		  '(' * sp * (V'parlist' * sp)^-1 * ')' * sp *  V'block' * sp * Kend
		;
	parlist =
		  V'namelist' * (sp * ',' * sp * '...')^-1 + '...'
		;
	tableconstructor =
		  '{' * sp * (V'fieldlist' * sp)^-1 * '}'
		;
	fieldlist =
		  V'field' * (sp * V'fieldsep' * sp * V'field')^0 * (sp * V'fieldsep')^-1
		;
	field =
		  '[' * sp * V'exp' * sp * ']' * sp * '=' * sp * V'exp'
		+ V'Name' * sp * '=' * sp * V'exp'
		+ V'exp'
		;
	fieldsep =
		  P','
		+ P';'
		;
	binop = -- match longest token sequences first
		  Kand
		+ Kor
		+ '..'
		+ '<='
		+ '>='
		+ '=='
		+ '~='
		+ P'&&' / ' and '
		+ P'||' / ' or '
		+ P'!=' / ' ~= '
		+ '+'
		+ '-'
		+ '*'
		+ '/'
		+ '^'
		+ '%'
		+ '<'
		+ '>'
		;
	unop =
		  P'-'
		+ P'#'
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