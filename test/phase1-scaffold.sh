#!/usr/bin/env bash
# Phase 1: verify binary exists and responds to --version and --help
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

assert_output_contains "--version prints version" "jamcrest" --version
assert_output_contains "--help prints usage"      "Usage"     --help
