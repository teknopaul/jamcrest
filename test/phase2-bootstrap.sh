#!/usr/bin/env bash
# Phase 2: V8 initializes and loads JS files correctly
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures"

# Normal run with valid files succeeds (V8 initializes OK)
assert_match "V8 loads JS and runs compare" "$FIXTURES/alice.json" "$FIXTURES/alice-matcher.js"

# Broken JS file via env override → non-zero exit with filename in stderr
TMPDIR_P2=$(mktemp -d)
cp "$(dirname "${BASH_SOURCE[0]}")/../src/js/"*.js "$TMPDIR_P2/"
echo "function bootstrap( { return 'ok'; }" > "$TMPDIR_P2/jamcrest-bootstrap.js"

set +e
out=$(JAMCREST_JS_DIR="$TMPDIR_P2" "$BINARY" --matcher "$FIXTURES/alice-matcher.js" \
      < "$FIXTURES/alice.json" 2>&1)
rc=$?
set -e

if [ "$rc" -ne 0 ] && echo "$out" | grep -q "jamcrest-bootstrap.js"; then
    pass "broken JS produces file:line error"
else
    fail "broken JS should exit non-zero with file reference (rc=$rc, out=$out)"
fi

rm -rf "$TMPDIR_P2"
