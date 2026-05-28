#!/usr/bin/env bash
# Test helpers for jamcrest bash test suite
BINARY="${BINARY:-$(dirname "${BASH_SOURCE[0]}")/../target/jamcrest}"
_PASS=0
_FAIL=0

pass() {
    local label="${1:-}"
    _PASS=$((_PASS + 1))
    echo "  PASS${label:+: $label}"
}

fail() {
    local label="${1:-}"
    _FAIL=$((_FAIL + 1))
    echo "  FAIL${label:+: $label}"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$label"
    else
        fail "$label (expected='$expected' got='$actual')"
    fi
}

# Runs binary with --matcher <matcher_file> and stdin from <input_file>.
# Returns binary exit code via $?.
_run_binary() {
    local input_file="$1" matcher_file="$2"
    shift 2
    "$BINARY" --matcher "$matcher_file" "$@" < "$input_file"
}

assert_match() {
    local label="$1" input_file="$2" matcher_file="$3"
    shift 3
    if _run_binary "$input_file" "$matcher_file" "$@" 2>/dev/null; then
        pass "$label"
    else
        fail "$label (expected exit 0, got exit $?)"
    fi
}

assert_no_match() {
    local label="$1" input_file="$2" matcher_file="$3"
    shift 3
    local rc=0
    _run_binary "$input_file" "$matcher_file" "$@" 2>/dev/null || rc=$?
    if [ "$rc" -eq 1 ]; then
        pass "$label"
    else
        fail "$label (expected exit 1, got exit $rc)"
    fi
}

assert_usage_error() {
    local label="$1"
    shift
    local rc=0
    "$BINARY" "$@" < /dev/null 2>/dev/null || rc=$?
    if [ "$rc" -eq 2 ]; then
        pass "$label"
    else
        fail "$label (expected exit 2, got exit $rc)"
    fi
}

assert_output_contains() {
    local label="$1" pattern="$2"
    shift 2
    local out
    out=$("$BINARY" "$@" < /dev/null 2>&1) || true
    if echo "$out" | grep -q "$pattern"; then
        pass "$label"
    else
        fail "$label (pattern '$pattern' not found in output: $out)"
    fi
}

print_summary() {
    echo ""
    echo "Results: $_PASS passed, $_FAIL failed"
    [ "$_FAIL" -eq 0 ]
}
