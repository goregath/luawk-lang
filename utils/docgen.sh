#!/usr/bin/env bash

set -ex
shopt -s globstar

cd "${0%/*}/.."
mkdir -p doc/
rm -rf doc/*

ldoc .

mkdir -p doc/examples
cd doc/examples
../../utils/locco/locco.lua ../../examples/**/*.luawk
