#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures/templating"

assert_template() {
    local label="$1" tpl="$2" data="$3" expected_file="$4"
    local out expected rc=0
    out=$("$BINARY" --template "$tpl" --data "$data" 2>/dev/null) || rc=$?
    expected=$(cat "$expected_file")
    if [ "$rc" -ne 0 ]; then
        fail "$label (exit $rc)"
    elif [ "$out" = "$expected" ]; then
        pass "$label"
    else
        fail "$label (got='$out' want='$expected')"
    fi
}

assert_template "login template" \
    "$FIXTURES/login/template.req.js" \
    "$FIXTURES/login/data.js" \
    "$FIXTURES/login/expected.json"

assert_template "config template" \
    "$FIXTURES/config/template.req.js" \
    "$FIXTURES/config/data.js" \
    "$FIXTURES/config/expected.json"

print_summary
