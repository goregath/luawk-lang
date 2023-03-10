#!/bin/sh

code=0

for test in test/test-*.lua; do
	echo "# $test" >&2
	lua -l test="${test%.lua}" -e 'if not test:run() then os.exit(1) end' || code=1
	echo >&2
done

exit "$code"