[![CI](https://github.com/goregath/luawk/actions/workflows/ci.yml/badge.svg)](https://github.com/goregath/luawk/actions/workflows/ci.yml)

Luawk Beta
==========

**DISCLAIMER: This application is currently in an early stage.**
**Feel free to play around but do not assume production ready code.**

State of Development
--------------------
Despite all efforts to support *Lua 5.1* and *LuaJIT*, this project is tested against a more recent version of *Lua 5.4*
with [luaposix].

Please have a look at the [test/] folder to see what features are currently supported. There are two kinds of tests,
unit test use a simple Lua test suite (see `test/*.lua`), integration and command-line tests are run with [bats] (see
`test/*.bats`).

There are also ongoing attempts to switch from pure Lua to a more elegant dialect for Luawk. A very intereseting
candidate would be [erde-lang/erde][erde-lang] that has recently become stable.

---

Synopsis
========

Luawk is an AWK-alike, data-driven programming language written in Lua.

This project is currently in an alpha stage and may introduce breaking changes in the future.

```plain
Usage: luawk [OPTIONS] [-F value] [-v var=value] [--] 'program' [file ...]
       luawk [OPTIONS] [-F value] [-v var=value] [-f file] [--] [file ...]

   -F value       Sets the field separator, FS, to value.
   -e program     Add source code to program.
   -f file        Program text is read from file instead of the command line.
   -m name        Import a program using LUAWK_PATH.
   -l name        Require a lua module name.
   -l var=name    Require a lua module name to global var.
   -o option      Modify runtime environment, see `-o help`.
   -v var=value   Assigns value to program variable var.
```

Example:

```bash
echo 'a:b:c' | luawk -F: '{ print $2 }' # yields: b
```

Description
===========

At its core Luawk is a domain-specific language for processing textutal data. Although not a direct clone of AWK, many
ideas and concepts apply for Luawk. The overall program structure for example is very close to AWK while the actions
itself are expressed in a grammar very close to Lua.

Luawk builds on top of [erde][erde-lang] with extended grammar written in [LPeg][lpeg] combining language features from
Lua and Awk.

* GNU AWK Extensions
* POSIX

Language Features
-----------------

### Field Reference / Dollar Sign Operator `$`

The dollar sign operator `$` is an unary operator that denotes a field reference in AWK, that is an expression prefixed
with `$` evaluates to an index of a field in the current record. A field reference in turn is a non-negative integer
constant. For example `$1` references the first field of the current record and `$NF` is last one. Here `NF` is a
special variable linked to the total number of fields of the current record. The special field `$0` is the current
record itself. An expression of `$(NF-1)` could be used to get the second last field. Please note the use of parenthesis
here, the `$` operator has the highest precedence of all operators.

So far we looked at the dollar operator from an AWK point of view.

*TODO*

Syntax
------

The syntax of Luawk is a superset of Lua 5.1 with additional syntactic sugar from AWK.

Program Structure
-----------------

### User-Defined Functions

    function name(...) do ... end
    local function name(...) do ... end

Top level function definitions are translated into a single *BEGIN* action that is executed before any other actions.
The listing above is equivalent to the following construct.

    BEGIN {
        function name(...) do ... end
        local function name(...) do ... end
    }

## Pattern-Action Pairs

    pattern
    { action }
    pattern { action }

## Special Actions

    BEGIN { action }
    END { action }
    BEGINFILE { action }
    ENDFILE { action }

# Syntax

TODO

# AWK Compatibility

TODO

## Supported I/O Statements

The following statements are syntactically equivalent to a lua *return statement*, thus no parenthesis are required.
They can appear anywhere in code, that are expressions or statements, in contrast to a return statement that is only
valid as a last statement in a block. There are some exceptions to the rule as you can see in the following table.

|                      | **exit** | **getline** | **next** | **nextfile\*** | **print** | **printf** |
|---------------------:|:--------:|:-----------:|:--------:|:--------------:|:---------:|:----------:|
|          **BEGIN**   |     x    |      x      |          |                |     x     |      x     |
|            **END**   |     x    |      x      |          |                |     x     |      x     |
|      **BEGINFILE**\* |     x    |             |          |        x       |     x     |      x     |
|        **ENDFILE**\* |     x    |             |          |                |     x     |      x     |
| **pattern-action**   |     x    |      x      |     x    |        x       |     x     |      x     |
| **user functions**   |     x    |      x      |     x    |        x       |     x     |      x     |

\* *GNU extension*

[test/]: test/
[bats]: https://bats-core.readthedocs.io/
[erde-lang]: https://erde-lang.github.io/
[lpeg]: https://www.inf.puc-rio.br/~roberto/lpeg/
[lpeglabel]: https://github.com/sqmedeiros/lpeglabel
[luaposix]: http://luaposix.github.io/luaposix
