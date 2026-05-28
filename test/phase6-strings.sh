#!/usr/bin/env bash
# Phase 6: string matchers
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FS="$(dirname "${BASH_SOURCE[0]}")/fixtures/strings"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# containsString
echo '({val: containsString("World")})' > "$tmpm"; assert_match    "containsString passes"   "$FS/hello.json" "$tmpm"
echo '({val: containsString("xyz")})' > "$tmpm";   assert_no_match "containsString fails"     "$FS/hello.json" "$tmpm"

# startsWith
echo '({val: startsWith("Hello")})' > "$tmpm"; assert_match    "startsWith passes"   "$FS/hello.json" "$tmpm"
echo '({val: startsWith("World")})' > "$tmpm"; assert_no_match "startsWith fails"    "$FS/hello.json" "$tmpm"

# endsWith
echo '({val: endsWith("World")})' > "$tmpm";  assert_match    "endsWith passes"  "$FS/hello.json" "$tmpm"
echo '({val: endsWith("Hello")})' > "$tmpm";  assert_no_match "endsWith fails"   "$FS/hello.json" "$tmpm"

# startsWithIgnoringCase
echo '({val: startsWithIgnoringCase("hello")})' > "$tmpm"; assert_match "startsWithIC passes" "$FS/hello.json" "$tmpm"

# emptyString
echo '({val: emptyString()})' > "$tmpm"; assert_match    "emptyString passes" "$FS/empty.json" "$tmpm"
echo '({val: emptyString()})' > "$tmpm"; assert_no_match "emptyString fails"  "$FS/hello.json" "$tmpm"

# hasLength
echo '({val: hasLength(11)})' > "$tmpm"; assert_match    "hasLength(11) passes Hello World" "$FS/hello.json" "$tmpm"
echo '({val: hasLength(5)})' > "$tmpm";  assert_no_match "hasLength(5) fails Hello World"  "$FS/hello.json" "$tmpm"
echo '({val: hasLength(0)})' > "$tmpm";  assert_match    "hasLength(0) passes empty"        "$FS/empty.json" "$tmpm"

# matchesPattern (string pattern)
echo '({val: matchesPattern("^Hello")})' > "$tmpm"; assert_match    "matchesPattern passes" "$FS/hello.json" "$tmpm"
echo '({val: matchesPattern("^World")})' > "$tmpm"; assert_no_match "matchesPattern fails"  "$FS/hello.json" "$tmpm"

# matchesRegex (alias)
echo '({val: matchesRegex(/world/i)})' > "$tmpm"; assert_match    "matchesRegex passes" "$FS/hello.json" "$tmpm"
echo '({val: matchesRegex(/^world/i)})' > "$tmpm"; assert_no_match "matchesRegex fails anchored" "$FS/hello.json" "$tmpm"
