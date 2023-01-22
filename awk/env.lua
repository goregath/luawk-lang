--- AWK environment.
-- @alias _env
-- @module env

--- Exported functions
local export = {}

--- AWK environment
local _env = {}

--- The number of elements in the @{ARGV} array.
_env.ARGC = 0

--- An array of command line arguments, excluding options and the program
--  argument, numbered from zero to @{ARGC}-1. The arguments in @{ARGV} can be
--  modified or added to; @{ARGC} can be altered. As each input file ends, awk
--  shall treat the next non-null element of @{ARGV}, up to the current value of
--  @{ARGC}-1, inclusive, as the name of the next input file. Thus, setting an
--  element of @{ARGV} to null means that it shall not be treated as an input
--  file. The name `'-'` indicates the standard input. If an argument matches the
--  format of an assignment operand, this argument shall be treated as an
--  assignment rather than a file argument.
_env.ARGV = {}

--- The printf format for converting numbers to strings (except for output
--  statements, where @{OFMT} is used); `"%.6g"` by default.
_env.CONVFMT = "%.6g"

--- An array representing the value of the environment, as described in the exec
--  functions defined in the System Interfaces volume of POSIX.1-2017. The
--  indices of the array shall be strings consisting of the names of the
--  environment variables, and the value of each array element shall be a
--  string consisting of the value of that variable. If appropriate, the
--  environment variable shall be considered a numeric string (see Expressions
--  in awk); the array element shall also have its numeric value. In all cases
--  where the behavior of awk is affected by environment variables
--  (including the environment of any commands that awk executes via the system
--  function or via pipeline redirections with the print statement, the printf
--  statement, or the getline function), the environment used shall be the
--  environment at the time awk began executing; it is implementation-defined
--  whether any modification of @{ENVIRON} affects this environment.
_env.ENVIRON = setmetatable({}, {
	__index = function(_, k) return os.getenv(k) end,
	-- TODO fake setenv
	__newindex = error
})

--- A pathname of the current input file. Inside a _BEGIN_ action the value is
--  undefined. Inside an _END_ action the value shall be the name of the last
--  input file processed.
_env.FILENAME = 0

--- The ordinal number of the current record in the current file. Inside a _BEGIN_
--  action the value shall be zero. Inside an _END_ action the value shall be the
--  number of the last record processed in the last file processed.
_env.FNR = 0

--- Input field separator regular expression; a _space_ by default.
_env.FS = '\x20'

--- The number of fields in the current record. Inside a _BEGIN_ action, the use
--  of @{NF} is undefined unless a getline function without a var argument is
--  executed previously. Inside an _END_ action, @{NF} shall retain the value it had
--  for the last record read, unless a subsequent, redirected, getline function
--  without a var argument is performed prior to entering the _END_ action.
_env.NF = 0

--- The ordinal number of the current record from the start of input. Inside a
--  _BEGIN_ action the value shall be zero. Inside an _END_ action the value shall
--  be the number of the last record processed.
_env.NR = 0

--- The printf format for converting numbers to strings in output statements
--  (see Output Statements); `"%.6g"` by default. The result of the conversion is
--  unspecified if the value of @{OFMT} is not a floating-point format
--  specification.
_env.OFMT = "%.6g"

--- The print statement output field separator; _space_ by default.
_env.OFS = '\x20'

--- The print statement output record separator; a _newline_ by default.
_env.ORS = '\n'

--- The length of the string matched by the match function.
_env.RLENGTH = 0

--- The first character of the string value of @{RS} shall be the input record
--  separator; a _newline_ by default. If @{RS} contains more than one character,
--  the results are unspecified. If @{RS} is null, then records are separated by
--  sequences consisting of a _newline_ plus one or more blank lines, leading
--  or trailing blank lines shall not result in empty records at the beginning
--  or end of the input, and a _newline_ shall always be a field separator, no
--  matter what the value of @{FS} is.
_env.RS = '\n'

--- The starting position of the string matched by the match function, numbering
--  from 1. This shall always be equivalent to the return value of the match
--  function.
_env.RSTART = 0

--- Create a new environment
function export.new()
	return setmetatable({}, {})
end

return export