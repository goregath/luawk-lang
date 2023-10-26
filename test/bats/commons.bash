#!/bin/bash

# shellcheck disable=SC2155,SC2164

export BATS_TEST_TIMEOUT=1
export LUAWK_PATH="examples/modules/?.luawk"

luawk() {
	timeout 3 /usr/bin/env luawk -lluacov "$@"
}

cd "${BATS_TEST_DIRNAME}/.."
