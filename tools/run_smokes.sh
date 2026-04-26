#!/usr/bin/env bash
# Phase 7 QA runner. Executes every star-reach/scripts/tests/smoke_*.tscn in
# headless Godot, classifies each as PASSED / FAILED based on the final print,
# and emits a summary. Non-zero exit on any failure so CI can gate on it.
#
# Usage:
#   tools/run_smokes.sh                # use GODOT env override or default path
#   GODOT=/path/to/godot tools/run_smokes.sh
#
# Notes:
#   - class_name registration: if you add new `class_name` scripts since last
#     editor session, run `"$GODOT" --path star-reach --editor --headless --quit`
#     once to rebuild the global class cache before running the smokes.
#   - All smokes should print a final "PASSED" on success. Anything else is
#     treated as a failure (FAILED explicitly or crash / hang / parse error).

set -u

GODOT_DEFAULT="/c/Program Files/Godot/Godot_v4.6.2-stable_win64_console.exe"
GODOT="${GODOT:-$GODOT_DEFAULT}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/star-reach"
TESTS_DIR="$PROJECT_DIR/scripts/tests"

if [[ ! -x "$GODOT" && ! -f "$GODOT" ]]; then
    echo "Godot not found at: $GODOT" >&2
    echo "Set GODOT env var to your Godot console executable." >&2
    exit 2
fi

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "Tests dir missing: $TESTS_DIR" >&2
    exit 2
fi

mapfile -t TSCN_FILES < <(find "$TESTS_DIR" -maxdepth 1 -name 'smoke_*.tscn' | sort)
if [[ ${#TSCN_FILES[@]} -eq 0 ]]; then
    echo "No smoke_*.tscn found in $TESTS_DIR" >&2
    exit 2
fi

PASS=0
FAIL=0
FAILED_NAMES=()

echo "=== StarReach QA smoke run ==="
echo "Godot:   $GODOT"
echo "Project: $PROJECT_DIR"
echo "Tests:   ${#TSCN_FILES[@]}"
echo

for tscn in "${TSCN_FILES[@]}"; do
    name=$(basename "$tscn" .tscn)
    rel="res://scripts/tests/${name}.tscn"
    output=$("$GODOT" --path "$PROJECT_DIR" --headless "$rel" 2>&1)
    # Consider PASSED only when the exact line appears on its own in stdout.
    if grep -q '^PASSED$' <<<"$output"; then
        echo "  [PASS]  $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL]  $name"
        echo "----- last 10 lines of $name output -----"
        tail -n 10 <<<"$output" | sed 's/^/          /'
        echo "------------------------------------------"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
    fi
done

echo
echo "=== Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "  Failing tests:"
    for n in "${FAILED_NAMES[@]}"; do
        echo "    - $n"
    done
    exit 1
fi
echo "  All smokes passed."
exit 0
