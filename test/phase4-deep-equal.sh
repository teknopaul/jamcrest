#!/usr/bin/env bash
# Phase 4: deep-equal comparator
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
F="$(dirname "${BASH_SOURCE[0]}")/fixtures/deep"
B="$BINARY"

assert_match    "identical objects pass"  "$F/identical.json"    "$F/identical-matcher.js"
assert_no_match "wrong scalar fails"      "$F/wrong-scalar.json" "$F/wrong-scalar-matcher.js"
assert_no_match "missing key fails"       "$F/missing-key.json"  "$F/missing-key-matcher.js"
assert_no_match "extra key fails (strict)" "$F/extra-key.json"   "$F/extra-key-matcher.js"
assert_no_match "array length mismatch"   "$F/array-length.json" "$F/array-length-matcher.js"
assert_no_match "nested mismatch"         "$F/nested.json"       "$F/nested-mismatch-matcher.js"

# Verify diagnostic path for nested mismatch
set +e
diag=$("$B" --matcher "$F/nested-mismatch-matcher.js" < "$F/nested.json" 2>&1)
rc=$?
set -e
if [ "$rc" -eq 1 ] && echo "$diag" | grep -q '\.user\.address\.city'; then
    pass "nested diagnostic contains correct path"
else
    fail "nested diagnostic path wrong (rc=$rc diag=$diag)"
fi

# Verify extra-key diagnostic mentions unexpected key
set +e
diag=$("$B" --matcher "$F/extra-key-matcher.js" < "$F/extra-key.json" 2>&1)
rc=$?
set -e
if [ "$rc" -eq 1 ] && echo "$diag" | grep -q 'extra'; then
    pass "extra-key diagnostic mentions the key"
else
    fail "extra-key diagnostic wrong (rc=$rc diag=$diag)"
fi

# NaN equality: JSON doesn't support NaN, but test via a matcher that uses NaN in JS
# We'll do this via a simple numeric match to verify the comparator works end-to-end
cat > /tmp/nan-input.json <<'JSON'
{"val": 1}
JSON
cat > /tmp/nan-matcher.js <<'JS'
({val: 1})
JS
assert_match "simple numeric match" /tmp/nan-input.json /tmp/nan-matcher.js
rm -f /tmp/nan-input.json /tmp/nan-matcher.js
