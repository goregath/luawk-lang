# luawk

[![CI](https://github.com/goregath/luawk/actions/workflows/ci.yml/badge.svg)](https://github.com/goregath/luawk/actions/workflows/ci.yml)

AWK for Lua

# LUAWK Overview

The syntax of LUAWK is a superset of Lua 5.1 with additional syntactic sugar from AWK.

## Program Structure

    function name(...) do ... end
    local function name(...) do ... end
    pattern
    { action }
    pattern { action }
    BEGIN { action }
    END { action }
    BEGINFILE { action }
    ENDFILE { action }

# LUAWK Syntax

## Operators

* Match Operator
* Dollar-Operator

## Patterns

* ERE Pattern

## Records

* Dollar-Operator

## User-Defined Functions

* Global scope
* Builtins can be replaced by user functions

# AWK Compatibility

## Supported I/O Statements

The following statements are syntactically equivalent to a lua *return statement*, thus no parenthesis are required.

|                    | **exit** | **getline** | **next** | **nextfile\*** | **print** | **printf** |
|-------------------:|:--------:|:-----------:|:--------:|:--------------:|:---------:|:----------:|
|          **BEGIN** |     x    |      x      |          |                |     x     |      x     |
|            **END** |     x    |      x      |          |                |     x     |      x     |
|      **BEGINFILE** |     x    |             |          |        x       |     x     |      x     |
|        **ENDFILE** |     x    |             |          |                |     x     |      x     |
| **pattern-action** |     x    |      x      |     x    |        x       |     x     |      x     |
| **user functions** |     x    |      x      |     x    |        x       |     x     |      x     |

\* *GNU extension*
