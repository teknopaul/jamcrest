#!/usr/bin/env bash
# Phase 9: README example end-to-end tests
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FR="$(dirname "${BASH_SOURCE[0]}")/fixtures/readme"

# README example 1: exact match (different key order in matcher is fine)
assert_match    "README exact match passes"  "$FR/alice.json" "$FR/exact-matcher.js"

# README example 2: anyNumber() matcher
assert_match    "README anyNumber() passes"  "$FR/alice.json" "$FR/any-number-matcher.js"

# Verify wrong name still fails with anyNumber()
tmpm=$(mktemp /tmp/matcher-XXXXXX.js)
trap 'rm -f "$tmpm"' EXIT
echo '({name: "Bob", id: anyNumber()})' > "$tmpm"
assert_no_match "anyNumber with wrong name fails" "$FR/alice.json" "$tmpm"

# Verify wrong type for id fails
echo '({name: "Alice", id: anyString()})' > "$tmpm"
assert_no_match "anyString() fails on number id" "$FR/alice.json" "$tmpm"
