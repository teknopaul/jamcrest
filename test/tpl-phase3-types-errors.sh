#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures/templating"

# Types
out=$("$BINARY" --template "$FIXTURES/types/template.req.js" \
    --data "$FIXTURES/types/data.js" 2>/dev/null)
assert_eq "all types render" "$(cat "$FIXTURES/types/expected.json")" "$out"

# Undefined variable → exit 2
rc=0
"$BINARY" --template "$FIXTURES/errors/undef-template.req.js" \
    --data "$FIXTURES/errors/undef-data.js" 2>/dev/null || rc=$?
assert_eq "undef var → exit 2" 2 "$rc"

# Syntax error in template → exit 2
rc=0
"$BINARY" --template "$FIXTURES/errors/bad-syntax.req.js" \
    --data "$FIXTURES/errors/undef-data.js" 2>/dev/null || rc=$?
assert_eq "syntax error → exit 2" 2 "$rc"

# Pipeline: render login template then assert with jamcrest --matcher
login_out=$("$BINARY" \
    --template "$FIXTURES/login/template.req.js" \
    --data    "$FIXTURES/login/data.js")
rc=0
echo "$login_out" | "$BINARY" \
    --matcher "$FIXTURES/login/matcher.js" 2>/dev/null || rc=$?
assert_eq "render→assert pipeline" 0 "$rc"

print_summary
