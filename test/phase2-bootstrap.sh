#!/usr/bin/env bash
# Phase 2: V8 initializes and embedded JS loads correctly
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures"

# Normal run confirms V8 + embedded JS are working
assert_match "embedded JS loads and compare runs" "$FIXTURES/alice.json" "$FIXTURES/alice-matcher.js"

# A broken matcher file (syntax error) still produces exit 2 with a location in stderr
tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT
echo '({syntax error' > "$tmpm"
set +e
out=$("$BINARY" --matcher "$tmpm" < "$FIXTURES/alice.json" 2>&1)
rc=$?
set -e
if [ "$rc" -eq 2 ] && echo "$out" | grep -q "$tmpm"; then
    pass "broken matcher produces file:line error"
else
    fail "broken matcher should exit 2 with location (rc=$rc out=$out)"
fi
