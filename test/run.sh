#!/bin/sh

for test in test/test-*.lua; do
	lua -l "test=${test%.lua}" -e 'test:run()'
done

