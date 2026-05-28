#!/usr/bin/env bash
# Phase 8: object/map matchers
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FO="$(dirname "${BASH_SOURCE[0]}")/fixtures/objects"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# hasKey
echo '(hasKey("name"))' > "$tmpm";    assert_match    "hasKey name passes"    "$FO/person.json"    "$tmpm"
echo '(hasKey("missing"))' > "$tmpm"; assert_no_match "hasKey missing fails"  "$FO/person.json"    "$tmpm"
echo '(hasKey("x"))' > "$tmpm";       assert_no_match "hasKey on empty fails" "$FO/empty-obj.json" "$tmpm"

# hasProperty without value matcher
echo '(hasProperty("city"))' > "$tmpm"; assert_match "hasProperty city passes" "$FO/person.json" "$tmpm"

# hasProperty with value matcher
cat > "$tmpm" <<'JS'
(hasProperty("name", containsString("Ali")))
JS
assert_match "hasProperty+containsString passes" "$FO/person.json" "$tmpm"
cat > "$tmpm" <<'JS'
(hasProperty("name", containsString("Bob")))
JS
assert_no_match "hasProperty+containsString fails" "$FO/person.json" "$tmpm"

# aMapWithSize
echo '(aMapWithSize(3))' > "$tmpm"; assert_match    "aMapWithSize(3) passes" "$FO/person.json"    "$tmpm"
echo '(aMapWithSize(1))' > "$tmpm"; assert_no_match "aMapWithSize(1) fails"  "$FO/person.json"    "$tmpm"
echo '(aMapWithSize(0))' > "$tmpm"; assert_match    "aMapWithSize(0) empty"  "$FO/empty-obj.json" "$tmpm"

# anEmptyMap
echo '(anEmptyMap())' > "$tmpm"; assert_match    "anEmptyMap passes"      "$FO/empty-obj.json" "$tmpm"
echo '(anEmptyMap())' > "$tmpm"; assert_no_match "anEmptyMap fails on person" "$FO/person.json" "$tmpm"
