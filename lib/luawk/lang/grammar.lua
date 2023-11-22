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
local blank = P(locale.space + brk + V'comment' - nl)
local sp = (blank^1)^-1
local brksp = ((blank + nl)^1)^-1
local eol = (P';' + nl)^1
local noident = -(locale.alnum + P'_')
local shebang = P"#" * (P(1) - nl)^0 * nl

local ufmt = {
	["$"] = "R[%1]",
	["!"] = "D(not(B(%1)))",
	["+"] = "D(%1)",
	["-"] = "-D(%1)",
}

local bfmt = {
	[".."] = "S(%1,%2)",
	["^" ] = "(D(%1)^D(%2))",
	["%" ] = "math.fmod(D(%1,%2))",
	["*" ] = "(D(%1)*D(%2))",
	["/" ] = "(D(%1)/D(%2))",
	["+" ] = "(D(%1)+D(%2))",
	["-" ] = "(D(%1)-D(%2))",
	["<" ] = "D(D(%1)<D(%2))",
	[">" ] = "D(D(%1)>D(%2))",
	["<="] = "D(D(%1)<=D(%2))",
	["!="] = "D(D(%1)~=D(%2))",
	["=="] = "D(D(%1)==D(%2))",
	[">="] = "D(D(%1)>=D(%2))",
	["=" ] = "V('%1',%2)", -- TODO arrays
	["&&"] = "A(%1,%2)",
	["||"] = "O(%1,%2)",
	["in"] = "D(%1[S(%2)]~=nil)",
	["~" ] = "match(S(%1,%2))",
	["!~"] = "D(0==match(S(%1,%2)))",
	["^="] = "V('%1',(D(%1)^D(%2)))", -- TODO arrays
	["%="] = "V('%1',math.fmod(D(%1,%2)))", -- TODO arrays
	["*="] = "V('%1',D(%1)*D(%2))", -- TODO arrays
	["/="] = "V('%1',D(%1)/D(%2))", -- TODO arrays
	["+="] = "V('%1',D(%1)+D(%2))", -- TODO arrays
	["-="] = "V('%1',D(%1)-D(%2))", -- TODO arrays
}

local function numconv(s)
	return string.format("%q",tonumber(s))
end

local function oct2dec(s)
	return tonumber(s, 8)
end

local function awkregexunquote(s)
	return s:gsub("\\/", "/")
end

local function concat(...)
	return table.concat({...}, "..SUBSEP..")
end

local function format(fmt, ...)
	local a = { ... }
	return fmt:gsub("%%(%d+)", function(i)
		return a[tonumber(i)]
	end)
end

local function group(type)
	return function(c, ...)
		if ... then
			return { type = type, c, ... }
		else
			return c
		end
	end
end

local function group_binary(c, ...)
	if ... then
		return { type = "binary", c, ... }
	else
		return c
	end
end

local group_unary = group "unary"

local function if_else(cond, stmt1, stmt2)
	print("IF_ELSE", cond, stmt1, stmt2)
	if stmt2 then
		return format("if B(%1) then %2 else %3 end", cond, stmt1, stmt2)
	else
		return format("if B(%1) then %2 end", cond, stmt1)
	end
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

local function new_function(name, params, action)
	print("NEW_FUNCTION", name, table.concat(params, ","), action)
end

local function print_special(name, params, op, exp)
	print("PRINT", name, params, op, exp)
end

local function getline_process(exp)
	print("GETLINE_PROC", exp)
end

local function getline_file(exp)
	print("GETLINE_FILE", exp)
end

local function pre_increment(lvalue)
	print("PRE_INCREMENT", lvalue)
end

local function pre_decrement(lvalue)
	print("PRE_DECREMENT", lvalue)
end

local function post_increment(lvalue)
	print("POST_INCREMENT", lvalue)
end

local function post_decrement(lvalue)
	print("POST_DECREMENT", lvalue)
end

local function eval_binary(l, op, r)
	print("EVAL_BINARY", l, op, r)
	if l == "getline" and op == "<" then
		return getline_file(r)
	end
	return format(bfmt[op], l, r)
end

local function eval_unary(op, r)
	print("EVAL_UNARY", op, r)
	return format(ufmt[op], r)
end

local function eval_ternary(cond, exp1, exp2)
	print("EVAL_TERNARY", cond, exp1, exp2)
	return string.format("(B(%s) and %s or %s)", cond, exp1, exp2)
end

local function eval_concat(...)
	return string.format("S(%s)", table.concat({...}, ","))
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

	-- shebang^-1 * V'newobj' * (blank + nl)^0 * (
	-- 	  ( ( V'globals' / table.insert * (blank + eol)^0 )^1 )^0
	-- 	* ( ( V'rule' / table.insert * (blank + eol)^0 )^1 )^0 * sp * -1
	-- );

	V'exp' / group();

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
		  V'actionblock'
		;

	actionblock =
		  Cg('{' * brksp * Cs(V'chunk'^-1) * sp * '}')
		;

	explist =
		  V'exp' * (sp * P',' * brksp * V'exp')^0 / group "explist"
		;

	namelist =
		  V'name' * (sp * P',' * sp * V'name')^0 / group "namelist"
		;

	valuelist =
		  V'value' * (sp * P',' * sp * V'value')^0 / group "valuelist"
		;

	chunk =
		  V'stmt' * (sp * eol * sp * V'stmt')^0 * (sp * eol)^0
		;

	simple_stmt =
		  P'delete' * noident * sp * Cs(V'name') * (P'[' * sp * Cs(V'arrayindex') * sp * P']')^-1
		  / delete
		+ C(P'print' * P'f'^-1) * noident * sp * P'(' * sp * Cs(V'explist'^0) * sp * P')' * (sp * V'output_redirection')^-1
		  / print_special
		+ C(P'print' * P'f'^-1) * noident * sp * Cs(V'explist'^0) * (sp * V'output_redirection')^-1
		  / print_special
		+ V'exp'
		+ sp * P';'
		;

	stmt =
		  P'if' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')' * brksp * Cs(V'stmt'^-1) * sp *
		  (P'else' * noident * brksp * Cs(V'stmt'))^-1
		  / if_else
		+ P'while' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')' * brksp * Cs(V'stmt'^-1)
		  / while_do
		+ P'do' * noident * brksp * Cs(V'stmt'^-1) * sp * P'while' * noident * sp * P'(' * sp * Cs(V'exp') * sp * P')'
		  / do_while
		+ P'for' * noident * sp * P'(' * Cs(V'name') * sp *
		  P'in' * noident * sp * Cs(V'name') * P')' * brksp * Cs(V'stmt'^-1)
		  / for_in
		+ P'for' * noident * sp * P'(' * sp *
		  Cs(V'simple_stmt') * sp * P';' * sp *
		  Cs(V'exp') * sp * P';' * sp *
		  Cs(V'simple_stmt') * sp * P')' * brksp * Cs(V'stmt'^-1)
		  / generic_for
		+ Cs(V'exp') * sp * P'|' * sp * P'getline' * noident / getline_process
		+ V'action'
		+ V'simple_stmt'
		;

	exp =
		  V'lvalue' * (sp * C(S'^%*/+-'^-1 * P'=') * brksp * V'exp') / group_binary
		+ V'ternary'
		;

	ternary =
		  V'binary_or' * sp * (P'?' * sp * V'exp' * sp * P':' * sp * V'exp')^-1 / group "ternary"
		;

	binary_or =
		  V'binary_and' * (sp * C(P'||') * brksp * V'binary_or')^0 / group_binary
		;

	binary_and =
		  V'binary_in' * (sp * C(P'&&') * brksp * V'binary_and')^0 / group_binary
		;

	binary_in =
		  P'(' * sp * (V'arrayindex' / group "arrayindex") * sp * P')' * sp *
		  C(P'in' * noident) * brksp * Vt'name' / group_binary
		+ V'binary_match' * (sp * C(P'in' * noident) * brksp * Vt'name')^-1 / group_binary
		;

	binary_match =
		  V'binary_comp' * (sp * C(P'!~' + P'~') * brksp * V'binary_match')^-1 / group_binary
		;

	binary_comp =
		  V'binary_concat' * (sp * C(S'<>!=' * P'=' + S'<>') * brksp * V'binary_comp')^-1 / group_binary
		;

	binary_concat =
		  V'binary_term' * (brksp * V'binary_term')^0 / group "concat"
		;

	binary_term =
		  -- V'binary_factor' * sp * (C(S'+-') * brksp * V'binary_factor')^1 / fold_binary
		  V'binary_factor' * sp * (C(S'+-') * brksp * V'binary_factor')^0 / group_binary
		;

	binary_factor =
		  V'binary_pow' * (sp * C(S'*/%') * brksp * V'binary_factor')^0 / group_binary
		;

	-- TODO '-+a'   valid
	-- TODO '+++a'  invalid
	-- TODO '+ ++a' valid
	-- TODO '!+!-a' valid
	-- TODO '- -a' valid
	-- TODO 'a^!a' valid

	unary_sign =
		  (C(P'!' + (P'+' * -P'+') + (P'-' * -P'-')) * sp) * V'binary_pow' / group_unary
		;

	binary_pow =
		  (V'unary_sign' + V'unary_terminal') * (sp * C(P'^') * brksp * (V'binary_pow'))^-1 / group_binary
		;


	unary_terminal =
		  C(P'$') * sp * V'unary_terminal' / group_unary
		+ Vt'lvalue' * sp * C(P'++' + P'--') / group "unary_post"
		+ C(P'++' + P'--') * sp * Vt'lvalue' / group_unary
		+ V'unary_sign'
		+ V'group'
		;

	group =
		  P'(' * sp * V'exp' * sp * P')'
		+ V'func_call'
		;

	func_call =
		  Vt'builtin_func' * noident * (sp * P'(' * sp * (V'explist')^-1 * sp * P')')^-1 / group "function"
		+ Vt'name' * noident * P'(' * sp * V'explist'^-1 * sp * P')' / group "function"
		+ V'value'
		;

	value =
		  -- P'getline' * noident
		  V'lvalue'
		+ Vt'number'
		+ Vt'string'
		+ Vt'regex'
		;

	lvalue =
		  -- TODO rule 'unary_field' may be left recursive
		  -- V'unary_field'
		  -- TODO $NF=1 and $(NF)=1
		  C(P'$') * sp * V'ternary' / group_unary
		+ Ct(V'name' * (sp * V'subscript')^-1)
		;

	subscript =
		  P'[' * sp * (V'arrayindex' / group "arrayindex") * sp * P']'
		;

	arrayindex =
		  Cg(V'exp' * (sp * P',' * brksp * V'exp')^0)
		;

	output_redirection =
		  C(P'>>' + S'>|') * sp * Cs(V'exp' - P'getline' * noident)
		;

	func_decl =
		  P'function' * noident * blank^1 * Cs(V'name') * sp *
		  '(' * sp * Ct(Cs(V'name') * (sp * P',' * sp * Cs(V'name'))^0) * sp * ')' * brksp * Cs(V'action')
		  / new_function
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
		  Cs((locale.alpha + '_') * (locale.alnum + '_')^0 - V'keyword')
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

	comment =
		  '#' * (P(1) - nl)^0 * (nl + -P(1))
		;

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
