#!/usr/bin/env bash
# Comparator factories: localeCompare and compareByField
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FC="$(dirname "${BASH_SOURCE[0]}")/fixtures/comparators"

tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT

# --- localeCompare ---

# default locale: ASCII order, case-insensitive via sensitivity
cat > "$tmpm" <<'JS'
({words: anySorted(["abricot","eclair","été","zèbre"], localeCompare())})
JS
assert_match "localeCompare() default sorts strings" "$FC/words-fr.json" "$tmpm"

# different values should fail
cat > "$tmpm" <<'JS'
({words: anySorted(["abricot","eclair","été","mango"], localeCompare())})
JS
assert_no_match "localeCompare() wrong values fails" "$FC/words-fr.json" "$tmpm"

# explicit locale "fr-FR" — accented chars sort after base letters
cat > "$tmpm" <<'JS'
({words: anySorted(["abricot","eclair","été","zèbre"], localeCompare("fr-FR"))})
JS
assert_match "localeCompare(fr-FR) locale-aware sort" "$FC/words-fr.json" "$tmpm"

# fr-FR with sensitivity:"base" treats é and e as equal — ordering within those is stable
# Here we just verify it accepts the option without throwing
cat > "$tmpm" <<'JS'
({words: anySorted(["abricot","eclair","été","zèbre"], localeCompare("fr-FR", {sensitivity:"base"}))})
JS
assert_match "localeCompare with options accepted" "$FC/words-fr.json" "$tmpm"

# --- compareByField: top-level field ---

# sort people by numeric id ascending: [1,2,3]
cat > "$tmpm" <<'JS'
({people: anySorted(
  [{id:1,name:"Alice"},{id:2,name:"Bob"},{id:3,name:"Charlie"}],
  compareByField("id")
)})
JS
assert_match "compareByField(id) numeric asc" "$FC/people.json" "$tmpm"

# wrong values should fail (id:99 not in input)
cat > "$tmpm" <<'JS'
({people: anySorted(
  [{id:1,name:"Alice"},{id:2,name:"Bob"},{id:99,name:"Nobody"}],
  compareByField("id")
)})
JS
assert_no_match "compareByField(id) wrong values fails" "$FC/people.json" "$tmpm"

# sort people by name lexicographically: Alice, Bob, Charlie
cat > "$tmpm" <<'JS'
({people: anySorted(
  [{id:1,name:"Alice"},{id:2,name:"Bob"},{id:3,name:"Charlie"}],
  compareByField("name")
)})
JS
assert_match "compareByField(name) string sort" "$FC/people.json" "$tmpm"

# --- compareByField: nested dot-notation path ---

# sort users by profile.score ascending: 10, 50, 80
cat > "$tmpm" <<'JS'
({users: anySorted(
  [{profile:{score:10,email:"alice@x.com"}},{profile:{score:50,email:"bob@x.com"}},{profile:{score:80,email:"charlie@x.com"}}],
  compareByField("profile.score")
)})
JS
assert_match "compareByField(profile.score) nested path" "$FC/nested.json" "$tmpm"

# sort users by profile.email lexicographically
cat > "$tmpm" <<'JS'
({users: anySorted(
  [{profile:{score:10,email:"alice@x.com"}},{profile:{score:50,email:"bob@x.com"}},{profile:{score:80,email:"charlie@x.com"}}],
  compareByField("profile.email")
)})
JS
assert_match "compareByField(profile.email) nested string" "$FC/nested.json" "$tmpm"

# --- compareByField composed with localeCompare ---

cat > "$tmpm" <<'JS'
({people: anySorted(
  [{id:1,name:"Alice"},{id:2,name:"Bob"},{id:3,name:"Charlie"}],
  compareByField("name", localeCompare("en"))
)})
JS
assert_match "compareByField + localeCompare composed" "$FC/people.json" "$tmpm"
