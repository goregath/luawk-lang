#!/usr/bin/env bash

set -ex
shopt -s globstar

cd "${0%/*}/.."
mkdir -p doc/
rm -rf doc/*
mkdir -p doc/

ldoc .

mkdir -p doc/examples
pushd doc/examples
../../utils/locco/locco.lua ../../examples/**/*.luawk
popd

mkdir -p doc/test
luacov