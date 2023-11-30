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
	R.lpeglabel = assert(L("./loadall.so", "luaopen_lpeglabel"))
	R.relabel   = assert(L("./loadall.so", "luaopen_relabel"))
	local m = loadfile('/dev/fd/3')()
	for _, chunk in ipairs(arg) do
		local program, msg, _, line, col = m.parse(chunk)
		if program then r("", program)
		else io.stderr:write("error: ", msg, " at line ", line or "?", " col ", col or "?", "\n") os.exit(1) end
		require 'pl.pretty'.dump(program)
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

local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V

local C = lpeg.C
local Cb = lpeg.Cb
local Cc = lpeg.Cc
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Cs = lpeg.Cs
local Ct = function(p) print(p) return lpeg.Ct(p) end
local Vt = function(name) print(name) return Ct(V(name)) end

local nl = P'\n'
local brk = P'\\\n'
local comment = P'#' * (P(1) - nl)^0 * (nl + -P(1))
local blank = P(locale.space + brk + comment - nl)
local sp = (blank^1)^-1
local brksp = ((blank + nl)^1)^-1
local eol = (P';' + nl)^1
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - nl)^0 * nl

local Kbegin = P'BEGIN' * noident
local Kbreak = P'break' * noident
local Kcontinue = P'continue' * noident
local Kdelete = P'delete' * noident
local Kdo = P'do' * noident
local Kelse = P'else' * noident
local Kend = P'END' * noident
local Kexit = P'exit' * noident
local Kfor = P'for' * noident
local Kfunction = P'function' * noident
local Kgetline = P'getline' * noident
local Kif = P'if' * noident
local Kin = P'in' * noident
local Knext = P'next' * noident
local Kprint = P'print' * noident
local Kprintf = P'printf' * noident
local Kreturn = P'return' * noident
local Kwhile = P'while' * noident

local function numconv(s)
	return string.format("%q",tonumber(s))
end

local function oct2dec(s)
	return tonumber(s, 8)
end

local function awkregexunquote(s)
	return s:gsub("\\/", "/")
end

local function _group_binary(a)
	local r = table.remove(a)
	local o = table.remove(a)
	return { type = "binary", #a > 1 and _group_binary(a) or a[1], o, r }
end

local function group_binary(c, ...)
	if ... then
		return _group_binary({ c, ... })
	elseif c then
		return c
	end
end

local function wrap(type)
	return function(...)
		return { type = type, ... }
	end
end

local wrap_keyword = wrap "keyword"

local function group(type)
	return function(c, ...)
		if ... then
			return { type = type, c, ... }
		else
			return c
		end
	end
end

local group_unary = group "unary"

local v = function(n) return V(n) * (sp * C(P'|') * sp * V'getline')^0 / group_binary end

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

	-- shebang^-1 * V'newobj' * (blank + nl)^0 * (
	-- 	  ( ( V'globals' / table.insert * (blank + eol)^0 )^1 )^0
	-- 	* ( ( V'rule' / table.insert * (blank + eol)^0 )^1 )^0 * sp * -1
	-- );

	V'stmt';

	globals =
		  Cb('program') * Cc('BEGIN') / rawget * Cs(V'func_decl')
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
		  P'BEGINFILE' * noident
		+ P'ENDFILE' * noident
		+ P'BEGIN' * noident
		+ P'END' * noident
		;

	action =
		  P'{' * brksp * (sp * eol)^0 * (V'chunk') * sp * P'}' / group "action"
		;

	explist =
		  V'exp' * (sp * P',' * brksp * V'exp')^0 / group "explist"
		;

	print_explist =
		  V'print_exp' * (sp * P',' * brksp * V'print_exp')^0 / group "explist"
		;

	namelist =
		  V'name' * (sp * P',' * sp * V'name')^0 / group "namelist"
		;

	valuelist =
		  V'value' * (sp * P',' * sp * V'value')^0 / group "valuelist"
		;

	arrayindex =
		  V'exp' * (sp * P',' * brksp * V'exp')^0 / group "arrayindex"
		;

	chunk =
		  V'action' * (sp * eol)^0 * sp * V'chunk'^-1
		+ V'stmt' * (sp * eol * sp * V'chunk')^-1 * sp * eol^0
		;

	simple_stmt =
		  Kdelete * sp * Vt'name'* (P'[' * sp * V'arrayindex' * sp * P']')^-1
		  / wrap "delete"
		-- TODO print 1 > "out"
		+ V'print' * sp * V'output_redirection'^-1 / group_binary
		-- + C(P'print' * P'f'^-1) * noident * sp * P'(' * sp * Cs(V'explist'^0) * sp * P')' * (sp * V'output_redirection')^-1
		--   / print_special
		-- + C(P'print' * P'f'^-1) * noident * sp * Cs(V'explist'^0) * (sp * V'output_redirection')^-1
		--   / print_special
		+ V'exp'
		;

	stmt =
		  Kif * sp * P'(' * sp * V'exp' * sp * P')' * brksp * V'stmt' * sp * (Kelse * brksp * V'stmt')^-1
		  / wrap "if_else"
		+ Kwhile * sp * P'(' * sp * V'exp' * sp * P')' * brksp * V'stmt'
		  / wrap "while"
		+ Kdo * brksp * V'stmt' * sp * Kwhile * sp * P'(' * sp * V'exp' * sp * P')'
		  / wrap "do_while"
		+ Kfor * sp * P'(' * sp * (Vt'name' * sp * C(Kin) * sp * Vt'name') / group_binary * sp * P')' * brksp * V'stmt'
		  / wrap "for_in"
		+ Kfor * sp * P'(' * sp *
		  (V'simple_stmt' + V'void') * sp * P';' * sp *
		  (V'exp' + V'void') * sp * P';' * sp *
		  (V'simple_stmt' + V'void') * sp * P')' * brksp * V'stmt'
		  / wrap "for"
		+ V'action'
		+ V'simple_stmt'
		+ V'void'
		;

	void =
		  Cc { type = "void" }
		;

	exp =
		  V'assignment'
		;

	print_exp =
		  V'print_assignment'
		;

	assignment =
		  V'lvalue' * (sp * C(S'^%*/+-'^-1 * P'=') * brksp * V'assignment') / group_binary
		+ V'ternary'
		;

	print_assignment =
		  V'lvalue' * (sp * C(S'^%*/+-'^-1 * P'=') * brksp * V'print_assignment') / group_binary
		+ V'print_ternary'
		;

	ternary =
		  V'binary_or' * sp * (P'?' * sp * V'assignment' * sp * P':' * sp * V'assignment')^-1 / group "ternary"
		;

	print_ternary =
		  V'print_binary_or' * sp * (P'?' * sp * V'print_assignment' * sp * P':' * sp * V'print_assignment')^-1 / group "ternary"
		;

	binary_or =
		  V'binary_and' * (sp * C(P'||') * brksp * V'binary_and')^0 / group_binary
		;

	print_binary_or =
		  V'print_binary_and' * (sp * C(P'||') * brksp * V'print_binary_and')^0 / group_binary
		;

	binary_and =
		  V'binary_in' * (sp * C(P'&&') * brksp * V'binary_in')^0 / group_binary
		;

	print_binary_and =
		  V'print_binary_in' * (sp * C(P'&&') * brksp * V'print_binary_in')^0 / group_binary
		;

	binary_in =
		  -- TODO BUG a in A == x
		  P'(' * sp * V'arrayindex' * sp * P')' * (sp * C(P'in' * noident) * brksp * Vt'name')^1 / group_binary
		+ V'binary_match' * (sp * C(P'in' * noident) * brksp * Vt'name')^0 / group_binary
		;

	print_binary_in =
		  -- TODO BUG a in A == x
		  P'(' * sp * V'arrayindex' * sp * P')' * (sp * C(P'in' * noident) * brksp * Vt'name')^1 / group_binary
		+ V'print_binary_match' * (sp * C(P'in' * noident) * brksp * Vt'name')^0 / group_binary
		;

	binary_match =
		  V'binary_comp' * (sp * C(P'!~' + P'~') * brksp * V'binary_comp')^0 / group_binary
		;

	print_binary_match =
		  V'print_binary_comp' * (sp * C(P'!~' + P'~') * brksp * V'print_binary_comp')^0 / group_binary
		;

	binary_comp =
		  V'binary_concat' * (sp * C(S'<>!=' * P'=' + S'<>') * brksp * V'binary_concat')^-1 / group_binary
		;

	print_binary_comp =
		  V'binary_concat' * (sp * C(S'<!=' * P'=' + P'<') * brksp * V'binary_concat')^-1 / group_binary
		;

	binary_concat =
		  v'binary_term' * (sp * v'binary_term')^0 / group "concat"
		;

	binary_term =
		  v'binary_factor' * sp * (C(S'+-') * brksp * v'binary_factor')^0 / group_binary
		;

	binary_factor =
		  v'binary_pow' * (sp * C(S'*/%') * brksp * v'binary_pow')^0 / group_binary
		;

	-- TODO '-+a'   valid
	-- TODO '+++a'  invalid
	-- TODO '+ ++a' valid
	-- TODO '!+!-a' valid
	-- TODO '- -a' valid
	-- TODO 'a^!a' valid

	unary_sign =
		  (C(P'!' + (P'+' * -P'+') + (P'-' * -P'-')) * sp) * v'binary_pow' / group_unary
		;

	binary_pow =
		  (v'unary_sign' + v'unary_pp') * (sp * C(P'^') * brksp * (v'binary_pow'))^-1 / group_binary
		;

	unary_pp =
		  C(P'++' + P'--') * sp * V'lvalue' / group_unary
		+ V'lvalue' * (sp * C(P'++' + P'--'))^-1 / group "unary_post"
		+ v'unary_sign'
		+ V'group'
		;

	unary_field =
		  C(P'$') * sp * V'group' / group_unary
		;

	group =
		  P'(' * sp * V'exp' * sp * P')'
		+ V'func_call'
		;

	-- input_function =
	-- 	  -- TODO '{ "ls" | getline < getline < "/etc/passwd" }'
	-- 	  V'getline' * sp * C(P'<') * sp * V'exp' / group_binary
	-- 	+ V'value' * (sp * C(P'|') * sp * V'getline')^-1 / group_binary
	-- 	;

	func_call =
		  Vt'builtin_func' * noident * (sp * P'(' * sp * (V'explist')^-1 * sp * P')')^-1 / wrap "function"
		+ Vt'name' * P'(' * sp * (V'explist')^-1 * sp * P')' / wrap "function"
		+ V'value'
		;

	value =
		  V'getline'
		+ V'lvalue'
		+ Vt'number'
		+ Vt'string'
		+ Vt'regex'
		;

	lvalue =
		  V'unary_field'
		+ Ct(V'name' * -P'(' * (sp * V'subscript')^-1)
		;

	subscript =
		  P'[' * sp * V'arrayindex' * sp * P']'
		;

	output_redirection =
		  C(P'>>' + S'>|') * sp * V'exp'
		;

	func_decl =
		  Kfunction * blank^1 * Cs(V'name') * sp *
		  '(' * sp * Ct(Cs(V'name') * (sp * P',' * sp * Cs(V'name'))^0) * sp * ')' * brksp * Cs(V'action')
		;

	getline =
		  C(Kgetline) * (sp * V'lvalue')^-1 / wrap_keyword
		;

	print =
		  C(Kprintf + Kprint) * noident * sp * (V'print_explist' + P'(' * sp * V'print_explist'^-1 * sp * P')')^-1 / wrap_keyword
		;

	keyword =
		  P'break' * noident
		+ P'continue' * noident
		+ P'delete' * noident
		+ P'do' * noident
		+ P'else' * noident
		+ P'for' * noident
		+ P'function' * noident
		+ P'if' * noident
		+ P'in' * noident
		+ P'return' * noident
		+ P'while' * noident
		+ V'specialpattern'
		+ V'builtin'
		+ (V'builtin_func' * noident)
		;

	builtin =
		  P'exit' * noident
		+ P'getline' * noident
		+ P'next' * noident
		+ P'nextfile' * noident
		+ P'print' * noident
		+ P'printf' * noident
		;

	regex =
		  Cg(Cc'regex', 'type') *
		  Cs('/' * Cs((P'\\' * P(1) + (1 - P'/'))^0) * '/' / awkregexunquote)
		;

	name =
		  Cg(Cc'ident', 'type') *
		  C((locale.alpha + '_') * (locale.alnum + '_')^0 - V'keyword')
		;

	number =
		  Cg(Cc'number', 'type') *
		  Cs(S'+-'^-1 * (V'integer' + V'decimal') / numconv)
		;

	integer =
		  P'0' * S'xX' * locale.xdigit^1
		+ P'0' * R'07'^1 / oct2dec
		;

	decimal =
		  locale.digit^1 * (P'.' * locale.digit^1)^-1 * (S'eE' * S'+-'^-1 * locale.digit^1)^-1
		;

	string =
		  Cg(Cc'string', 'type') * (
		  P'"' * C('\\' * P(1) + (P(1) - '"')^0) * P'"'
		+ P"'" * C("\\" * P(1) + (P(1) - "'")^0) * P"'"
		);

	-- comment =
	-- 	  '#' * (P(1) - nl)^0 * (nl + -P(1))
	-- 	;

	builtin_func =
		  Cg(Cc'builtin', 'type') * C(
		  P'atan2'
		+ P'cos'
		+ P'sin'
		+ P'exp'
		+ P'log'
		+ P'sqrt'
		+ P'int'
		+ P'rand'
		+ P'srand'
		+ P'gsub'
		+ P'index'
		+ P'length'
		+ P'match'
		+ P'split'
		+ P'sprintf'
		+ P'sub'
		+ P'substr'
		+ P'tolower'
		+ P'toupper'
		+ P'close'
		+ P'system'
		);

	luareserved =
		  P'elseif'
		+ P'end'
		+ P'false'
		+ P'goto'
		+ P'local'
		+ P'nil'
		+ P'repeat'
		+ P'then'
		+ P'true'
		+ P'until'
		+ P'and'
		+ P'or'
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
