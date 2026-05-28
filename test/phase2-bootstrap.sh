#!/usr/bin/env bash
# Phase 2: V8 loads JS files and calls bootstrap()
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Normal startup calls bootstrap() which returns "ok"
out=$("$BINARY" 2>&1)
assert_eq "bootstrap returns ok" "ok" "$out"

# Broken JS file via env override
TMPDIR_PHASE2=$(mktemp -d)
cp "$(dirname "${BASH_SOURCE[0]}")/../src/js/"*.js "$TMPDIR_PHASE2/"

# Overwrite bootstrap with syntax error
echo "function bootstrap( { return 'ok'; }" > "$TMPDIR_PHASE2/jamcrest-bootstrap.js"
set +e
out=$(JAMCREST_JS_DIR="$TMPDIR_PHASE2" "$BINARY" 2>&1)
rc=$?
set -e
if [ "$rc" -ne 0 ] && echo "$out" | grep -q "jamcrest-bootstrap.js"; then
    pass "broken JS produces file:line error"
else
    fail "broken JS should exit non-zero with file reference (rc=$rc, out=$out)"
fi

rm -rf "$TMPDIR_PHASE2"
