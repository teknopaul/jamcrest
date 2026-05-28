#!/usr/bin/env bash
# Phase 8: logical combinators
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FL="$(dirname "${BASH_SOURCE[0]}")/fixtures/logical"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# not() — use --ignore-unknown since matchers only cover one key of mixed.json
echo '({label: not(emptyString())})' > "$tmpm"
assert_match    "not(emptyString) passes"  "$FL/mixed.json" "$tmpm" --ignore-unknown
echo '({code: not(anyNumber())})' > "$tmpm"
assert_no_match "not(anyNumber) fails num"  "$FL/mixed.json" "$tmpm" --ignore-unknown

# anyOf()
echo '({code: anyOf(equalTo(1), equalTo(2), equalTo(42))})' > "$tmpm"
assert_match    "anyOf passes on 42"          "$FL/mixed.json" "$tmpm" --ignore-unknown
echo '({code: anyOf(equalTo(1), equalTo(2), equalTo(3))})' > "$tmpm"
assert_no_match "anyOf fails when none match" "$FL/mixed.json" "$tmpm" --ignore-unknown

# either().or()
cat > "$tmpm" <<'JS'
({code: either(anyNumber()).or(anyString())})
JS
assert_match    "either(num).or(str) passes num"  "$FL/mixed.json" "$tmpm" --ignore-unknown

cat > "$tmpm" <<'JS'
({label: either(anyNumber()).or(anyString())})
JS
assert_match    "either(num).or(str) passes str"  "$FL/mixed.json" "$tmpm" --ignore-unknown

cat > "$tmpm" <<'JS'
({flag: either(anyNumber()).or(anyString())})
JS
assert_no_match "either(num).or(str) fails bool"  "$FL/mixed.json" "$tmpm" --ignore-unknown

# inCollection
echo '({code: inCollection([10, 42, 99])})' > "$tmpm"
assert_match    "inCollection passes" "$FL/mixed.json" "$tmpm" --ignore-unknown
echo '({code: inCollection([10, 99])})' > "$tmpm"
assert_no_match "inCollection fails"  "$FL/mixed.json" "$tmpm" --ignore-unknown
