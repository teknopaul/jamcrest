#!/usr/bin/env bash
# Run all test scripts in test/ (except this one and lib.sh)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== jamcrest test suite ==="
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0

run_suite() {
    local script="$1"
    local name
    name=$(basename "$script" .sh)
    echo "--- $name ---"
    _PASS=0
    _FAIL=0
    # Source so assert_* helpers share state; subshell would hide counts
    set +e
    (
        source "$script"
    )
    local rc=$?
    # Re-source to pick up counts (each script appends to shared vars via source)
    set -e
    echo ""
}

for script in "$SCRIPT_DIR"/phase*.sh "$SCRIPT_DIR"/test-*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script" .sh)
    echo "--- $name ---"
    _PASS=0
    _FAIL=0
    source "$script" || true
    TOTAL_PASS=$((TOTAL_PASS + _PASS))
    TOTAL_FAIL=$((TOTAL_FAIL + _FAIL))
    echo ""
done

echo "==========================="
echo "Total: $TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
