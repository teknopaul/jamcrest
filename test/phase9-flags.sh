#!/usr/bin/env bash
# Phase 9: flags and install verification
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FR="$(dirname "${BASH_SOURCE[0]}")/fixtures/readme"
FD="$(dirname "${BASH_SOURCE[0]}")/fixtures/deep"

# extra-fields.json has role/active; partial-matcher only checks name/id
# Without ignore-unknown → should FAIL (strict)
assert_no_match "strict mode rejects extra keys" "$FR/extra-fields.json" "$FR/partial-matcher.js"

# With --ignore-unknown → should PASS
assert_match    "--ignore-unknown allows extra keys" "$FR/extra-fields.json" "$FR/partial-matcher.js" --ignore-unknown

# --ignore-properties is a synonym
assert_match    "--ignore-properties synonym"  "$FR/extra-fields.json" "$FR/partial-matcher.js" --ignore-properties

# --quiet suppresses stderr on mismatch
tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT
echo '({name: "Bob"})' > "$tmpm"
set +e
stderr_out=$("$BINARY" --matcher "$tmpm" --quiet < "$FR/alice.json" 2>&1 >/dev/null)
rc=$?
set -e
if [ "$rc" -eq 1 ] && [ -z "$stderr_out" ]; then
    pass "--quiet suppresses diagnostic"
else
    fail "--quiet should suppress stderr (rc=$rc stderr='$stderr_out')"
fi

# Without --quiet, diagnostic appears on stderr
set +e
stderr_out=$("$BINARY" --matcher "$tmpm" < "$FR/alice.json" 2>&1 >/dev/null)
rc=$?
set -e
if [ "$rc" -eq 1 ] && [ -n "$stderr_out" ]; then
    pass "mismatch diagnostic appears on stderr"
else
    fail "mismatch should print diagnostic (rc=$rc stderr='$stderr_out')"
fi

# Install verification: install to /tmp/jc-install-test and verify JS is found
INSTALL_PREFIX=/tmp/jc-install-test
make -C "$(dirname "${BASH_SOURCE[0]}")/.." install PREFIX="$INSTALL_PREFIX" 2>/dev/null
set +e
v=$("$INSTALL_PREFIX/bin/jamcrest" --version 2>&1)
rc=$?
set -e
if [ "$rc" -eq 0 ] && echo "$v" | grep -q "jamcrest"; then
    pass "installed binary --version works"
else
    fail "install verification failed (rc=$rc out=$v)"
fi

# Run a match via installed binary to confirm JS files are discovered
set +e
echo '{"id":1234,"name":"Alice"}' | "$INSTALL_PREFIX/bin/jamcrest" --matcher "$FR/any-number-matcher.js" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    pass "installed binary finds JS files"
else
    fail "installed binary could not find JS files (exit $rc)"
fi

rm -rf "$INSTALL_PREFIX"
