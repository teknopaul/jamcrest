#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_output_contains "--help shows --template" "--template" --help
assert_output_contains "--help shows --data"     "--data"     --help

# --template without --data → exit 2
assert_usage_error "--template alone is error" --template /dev/null

# --data without --template → exit 2
assert_usage_error "--data alone is error" --data /dev/null

# --template + --matcher together → exit 2
assert_usage_error "--template and --matcher conflict" \
    --template /dev/null --matcher /dev/null

print_summary
