#!/usr/bin/env bash

set -ex
shopt -s globstar

cd "${0%/*}/.."
mkdir -p doc/
rm -rf doc/*

ldoc .
pycco -d doc/examples -l lua examples/**/*.luawk

# disable error highlighting
sed -e '/^body .err/ s#^#/*#' -i doc/examples/pycco.css