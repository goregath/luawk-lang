# luawk

[![CI](https://github.com/goregath/luawk/actions/workflows/ci.yml/badge.svg)](https://github.com/goregath/luawk/actions/workflows/ci.yml)

AWK for Lua

## Supported Keywords

|                    | **exit** | **next** | **nextfile\*** | **getline** |
|-------------------:|:--------:|:--------:|:--------------:|:-----------:|
|          **BEGIN** |     x    |          |                |      x      |
|            **END** |     x    |          |                |      x      |
|      **BEGINFILE** |     x    |          |        x       |             |
|        **ENDFILE** |     x    |          |                |             |
| **pattern-action** |     x    |     x    |        x       |      x      |

\* *GNU extension*
