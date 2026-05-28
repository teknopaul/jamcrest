#!/usr/bin/env bash
# Phase 7: array / collection matchers
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FA="$(dirname "${BASH_SOURCE[0]}")/fixtures/arrays"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# empty() / emptyArray()
echo '({items: empty()})' > "$tmpm";       assert_match    "empty() passes []"          "$FA/empty-arr.json" "$tmpm"
echo '({items: empty()})' > "$tmpm";       assert_no_match "empty() fails non-empty"     "$FA/nums.json"      "$tmpm"
echo '({items: emptyArray()})' > "$tmpm";  assert_match    "emptyArray() passes []"      "$FA/empty-arr.json" "$tmpm"

# arrayWithSize
echo '({items: arrayWithSize(5)})' > "$tmpm"; assert_match    "arrayWithSize(5) passes" "$FA/nums.json"      "$tmpm"
echo '({items: arrayWithSize(2)})' > "$tmpm"; assert_no_match "arrayWithSize(2) fails"  "$FA/nums.json"      "$tmpm"

# single-matcher-applied-to-all elements
echo '({items: [anyNumber()]})' > "$tmpm";  assert_match    "single matcher all pass"   "$FA/nums.json"      "$tmpm"
echo '({items: [anyString()]})' > "$tmpm";  assert_no_match "single matcher all fail"   "$FA/nums.json"      "$tmpm"
echo '({items: [anyString()]})' > "$tmpm";  assert_match    "single matcher strings"    "$FA/strings.json"   "$tmpm"

# arrayContaining
echo '({items: arrayContaining(3, 5)})' > "$tmpm"; assert_match    "arrayContaining passes" "$FA/nums.json" "$tmpm"
echo '({items: arrayContaining(99)})' > "$tmpm";   assert_no_match "arrayContaining fails"  "$FA/nums.json" "$tmpm"

# arrayContainingInAnyOrder with literals
echo '({items: arrayContainingInAnyOrder("apple","banana","cherry")})' > "$tmpm"
assert_match "arrayContainingInAnyOrder strings" "$FA/strings.json" "$tmpm"
echo '({items: arrayContainingInAnyOrder("apple","mango")})' > "$tmpm"
assert_no_match "arrayContainingInAnyOrder missing" "$FA/strings.json" "$tmpm"

# arrayContainingInAnyOrder with matchers
echo '({items: arrayContainingInAnyOrder(anyString(), anyString(), anyString())})' > "$tmpm"
assert_match "arrayContainingInAnyOrder matchers" "$FA/strings.json" "$tmpm"

# anySorted with string comparator
cat > "$tmpm" <<'JS'
({items: anySorted(["apple","banana","cherry"], function(a,b){ return a < b ? -1 : a > b ? 1 : 0; })})
JS
assert_match "anySorted strings" "$FA/strings.json" "$tmpm"

cat > "$tmpm" <<'JS'
({items: anySorted(["apple","banana","mango"], function(a,b){ return a < b ? -1 : a > b ? 1 : 0; })})
JS
assert_no_match "anySorted mismatch" "$FA/strings.json" "$tmpm"
