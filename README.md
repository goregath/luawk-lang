[![CI](https://github.com/goregath/luawk/actions/workflows/ci.yml/badge.svg)](https://github.com/goregath/luawk/actions/workflows/ci.yml)

Synopsis
========

LUAWK is an AWK-alike language and application written in Lua.

This project is currently in an alpha stage and may introduce breaking changes in the future.

Description
===========

At its core LUAWK is a domain-specific language for processing textutal data.
Although not a direct clone of AWK, many ideas and concepts apply for LUAWK.
The overall program structure for example is very close to AWK while the actions itself are expressed in a grammar very close to Lua.

* GNU AWK Extensions
* POSIX

Motiviation
-----------

LUAWK is an ongoing attempt to create a highly extensible version of AWK.

* Idea: Combine compactness of AWK with an extension language like Lua
* Benefit from Lua ecosystem
* Learn both langugaes
* Both great languages
* Lua is influenced by AWK in some ways
* Both languages naturally combine
* Combine the strengths and weaknesses of both
* Filter for structured data
* Initial idea: patch tarballs with awk
* Unsatisfactory Attempts: Patching busybox AWK, using libmawk

Overview
========

Syntax
------

The syntax of LUAWK is a superset of Lua 5.1 with additional syntactic sugar from AWK.

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
They can appear anywhere in code, that are expressions or statements, in contrast to a return statement that is only valid as a last statement in a block.
There are some exceptions to the rule as you can see in the following table.

|                      | **exit** | **getline** | **next** | **nextfile\*** | **print** | **printf** |
|---------------------:|:--------:|:-----------:|:--------:|:--------------:|:---------:|:----------:|
|          **BEGIN**   |     x    |      x      |          |                |     x     |      x     |
|            **END**   |     x    |      x      |          |                |     x     |      x     |
|      **BEGINFILE**\* |     x    |             |          |        x       |     x     |      x     |
|        **ENDFILE**\* |     x    |             |          |                |     x     |      x     |
| **pattern-action**   |     x    |      x      |     x    |        x       |     x     |      x     |
| **user functions**   |     x    |      x      |     x    |        x       |     x     |      x     |

\* *GNU extension*
