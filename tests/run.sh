#!/usr/bin/env bash
# Test runner: compiles every tests/<name>/test.typ (a test passes if it
# compiles — tests use `assert`/`panic` to fail) and checks the expected-failure
# probes in tests/expect-fail/ (each MUST fail to compile). An optional argument
# filters tests by substring of their path.
#
# The RELAX NG tests load the bundled plugin at src/relaxng/relaxng.wasm; if you
# changed the plugin sources, rebuild it first with plugin/build.sh.
set -u
cd "$(dirname "$0")/.."

fail=0
pass=0
filter="${1:-}"

# Positive tests: each tests/<name>/test.typ must compile cleanly.
for f in tests/*/test.typ; do
    name="${f#tests/}"
    if [[ -n "$filter" && "$name" != *"$filter"* ]]; then
        continue
    fi
    if out="$(typst compile --root . -f pdf "$f" /dev/null 2>&1)"; then
        pass=$((pass + 1))
        echo "PASS $name"
    else
        fail=$((fail + 1))
        echo "FAIL $name"
        echo "$out" | sed 's/^/     /'
    fi
done

# Expected-failure probes: each tests/expect-fail/*.typ MUST fail to compile
# (see tests/expect-fail/README.md).
for f in tests/expect-fail/*.typ; do
    name="${f#tests/}"
    if [[ -n "$filter" && "$name" != *"$filter"* ]]; then
        continue
    fi
    if typst compile --root . -f pdf "$f" /dev/null >/dev/null 2>&1; then
        fail=$((fail + 1))
        echo "FAIL $name (compiled cleanly, but was expected to fail)"
    else
        pass=$((pass + 1))
        echo "PASS $name (fails as expected)"
    fi
done

echo "----"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
