#!/bin/bash

# shellcheck disable=SC2155,SC2164

export BATS_TEST_TIMEOUT=1
export LUA_PATH="../src/?.lua;$(lua -e 'print(package.path)')"

luawk() {
	timeout 3 lua -lluacov ../src/luawk.lua "$@"
}

cd "$BATS_TEST_DIRNAME"