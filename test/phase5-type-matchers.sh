#!/usr/bin/env bash
# Phase 5: type matcher factories
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
F="$(dirname "${BASH_SOURCE[0]}")/fixtures/types"

# Helper: write inline matcher to a temp file and run
tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

run_m() {
    local input_file="$1" matcher_body="$2"
    echo "$matcher_body" > "$tmpm"
    "$BINARY" --matcher "$tmpm" < "$input_file" 2>/dev/null
}

# any(): non-null matches; null fails
echo '({val: any()})' > "$tmpm"
assert_match    "any() matches string"  "$F/string-val.json" "$tmpm"
echo '({val: any()})' > "$tmpm"
assert_no_match "any() fails on null"   "$F/null-val.json"   "$tmpm"

# anything(): always matches
echo '({val: anything()})' > "$tmpm"
assert_match    "anything() matches number"  "$F/number-val.json" "$tmpm"
echo '({val: anything()})' > "$tmpm"
assert_match    "anything() matches null"    "$F/null-val.json"   "$tmpm"

# anyBoolean()
echo '({val: anyBoolean()})' > "$tmpm"
assert_match    "anyBoolean() passes"      "$F/bool-val.json"   "$tmpm"
echo '({val: anyBoolean()})' > "$tmpm"
assert_no_match "anyBoolean() fails on str" "$F/string-val.json" "$tmpm"

# anyString()
echo '({val: anyString()})' > "$tmpm"
assert_match    "anyString() passes"      "$F/string-val.json" "$tmpm"
echo '({val: anyString()})' > "$tmpm"
assert_no_match "anyString() fails on num" "$F/number-val.json" "$tmpm"

# anyNumber()
echo '({val: anyNumber()})' > "$tmpm"
assert_match    "anyNumber() passes"      "$F/number-val.json" "$tmpm"
echo '({val: anyNumber()})' > "$tmpm"
assert_no_match "anyNumber() fails on str" "$F/string-val.json" "$tmpm"

# anyArray()
echo '({val: anyArray()})' > "$tmpm"
assert_match    "anyArray() passes"       "$F/array-val.json"  "$tmpm"
echo '({val: anyArray()})' > "$tmpm"
assert_no_match "anyArray() fails on num" "$F/number-val.json" "$tmpm"

# anyObject()
echo '({val: anyObject()})' > "$tmpm"
assert_match    "anyObject() passes"        "$F/object-val.json" "$tmpm"
echo '({val: anyObject()})' > "$tmpm"
assert_no_match "anyObject() fails on arr"  "$F/array-val.json"  "$tmpm"

# isA('string')
echo '({val: isA("string")})' > "$tmpm"
assert_match    "isA(string) passes"      "$F/string-val.json" "$tmpm"
echo '({val: isA("number")})' > "$tmpm"
assert_no_match "isA(number) fails on str" "$F/string-val.json" "$tmpm"

# notNullValue()
echo '({val: notNullValue()})' > "$tmpm"
assert_match    "notNullValue() passes on num" "$F/number-val.json" "$tmpm"
echo '({val: notNullValue()})' > "$tmpm"
assert_no_match "notNullValue() fails on null" "$F/null-val.json"   "$tmpm"

# blankOrNull()
echo '({val: blankOrNull()})' > "$tmpm"
assert_match    "blankOrNull() passes on null" "$F/null-val.json"   "$tmpm"
echo '({val: blankOrNull()})' > "$tmpm"
assert_no_match "blankOrNull() fails on num"  "$F/number-val.json" "$tmpm"
