#!/usr/bin/env bash
# Phase 6: comparison matchers
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FC="$(dirname "${BASH_SOURCE[0]}")/fixtures/comparison"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# greaterThan
echo '({val: greaterThan(5)})' > "$tmpm";  assert_match    "greaterThan(5) passes 10"  "$FC/num10.json" "$tmpm"
echo '({val: greaterThan(10)})' > "$tmpm"; assert_no_match "greaterThan(10) fails 10"  "$FC/num10.json" "$tmpm"
echo '({val: greaterThan(10)})' > "$tmpm"; assert_no_match "greaterThan(10) fails 5"   "$FC/num5.json"  "$tmpm"

# greaterThanOrEqualTo
echo '({val: greaterThanOrEqualTo(10)})' > "$tmpm"; assert_match "gTE(10) passes 10"  "$FC/num10.json" "$tmpm"
echo '({val: greaterThanOrEqualTo(11)})' > "$tmpm"; assert_no_match "gTE(11) fails 10" "$FC/num10.json" "$tmpm"

# lessThan
echo '({val: lessThan(20)})' > "$tmpm";  assert_match    "lessThan(20) passes 10"  "$FC/num10.json" "$tmpm"
echo '({val: lessThan(10)})' > "$tmpm";  assert_no_match "lessThan(10) fails 10"   "$FC/num10.json" "$tmpm"

# lessThanOrEqualTo
echo '({val: lessThanOrEqualTo(10)})' > "$tmpm"; assert_match    "lTE(10) passes 10" "$FC/num10.json" "$tmpm"
echo '({val: lessThanOrEqualTo(9)})' > "$tmpm";  assert_no_match "lTE(9) fails 10"   "$FC/num10.json" "$tmpm"

# closeTo: boundary cases
echo '({val: closeTo(10, 0)})' > "$tmpm";    assert_match    "closeTo(10,0) exact"      "$FC/num10.json" "$tmpm"
echo '({val: closeTo(9, 1)})' > "$tmpm";     assert_match    "closeTo(9,1) at boundary" "$FC/num10.json" "$tmpm"
echo '({val: closeTo(9, 0.9)})' > "$tmpm";   assert_no_match "closeTo(9,0.9) outside"   "$FC/num10.json" "$tmpm"

# equalTo
echo '({val: equalTo(10)})' > "$tmpm"; assert_match    "equalTo(10) passes" "$FC/num10.json" "$tmpm"
echo '({val: equalTo(5)})' > "$tmpm";  assert_no_match "equalTo(5) fails"   "$FC/num10.json" "$tmpm"

# equalToIgnoringCase
cat > "$tmpm" <<'JS'
({val: equalToIgnoringCase("hello world")})
JS
assert_match "equalToIgnoringCase passes" "$(dirname "${BASH_SOURCE[0]}")/fixtures/strings/hello.json" "$tmpm"
