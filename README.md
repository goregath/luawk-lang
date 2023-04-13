# luawk

[![CI](https://github.com/goregath/luawk/actions/workflows/ci.yml/badge.svg)](https://github.com/goregath/luawk/actions/workflows/ci.yml)

AWK for Lua

# AWK Compatibility

## Supported I/O Statements

|                    | **exit** | **getline** | **next** | **nextfile\*** | **print** | **printf** |
|-------------------:|:--------:|:-----------:|:--------:|:--------------:|:---------:|:----------:|
|          **BEGIN** |     x    |      x      |          |                |     x     |      x     |
|            **END** |     x    |      x      |          |                |     x     |      x     |
|      **BEGINFILE** |     x    |             |          |        x       |     x     |      x     |
|        **ENDFILE** |     x    |             |          |                |     x     |      x     |
| **pattern-action** |     x    |      x      |     x    |        x       |     x     |      x     |
| **user functions** |     x    |      x      |     x    |        x       |     x     |      x     |

\* *GNU extension*
