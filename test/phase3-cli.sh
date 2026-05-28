#!/usr/bin/env bash
# Phase 3: CLI arg parsing, stdin, matcher loading
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FIXTURES="$(dirname "${BASH_SOURCE[0]}")/fixtures"

# Basic match (stub always returns true)
assert_match      "alice match"   "$FIXTURES/alice.json" "$FIXTURES/alice-matcher.js"

# --help exits 0 and prints Usage
assert_output_contains "--help exits 0"    "Usage"    --help
assert_output_contains "--version has ver" "jamcrest"  --version

# Missing --matcher → exit 2
assert_usage_error "missing --matcher"

# Unknown flag → exit 2
assert_usage_error "unknown flag" --unknown-flag

# Unreadable matcher → exit 2
assert_usage_error "missing matcher file" --matcher /nonexistent/path.js

# Malformed JSON on stdin
set +e
echo "not-json" | "$BINARY" --matcher "$FIXTURES/alice-matcher.js" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "malformed JSON exits 2"
else fail "malformed JSON should exit 2 (got $rc)"; fi

# --quiet suppresses stderr on mismatch (stub always matches so just verify flag is accepted)
assert_match "quiet flag accepted" "$FIXTURES/alice.json" "$FIXTURES/alice-matcher.js" --quiet
