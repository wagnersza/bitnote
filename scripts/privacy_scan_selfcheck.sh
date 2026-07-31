#!/bin/bash
# Usage: bash scripts/privacy_scan_selfcheck.sh
#
# Self-check for scripts/privacy_scan.sh. Two cases:
#   1. clean tree -> privacy_scan.sh exits 0
#   2. tree with a planted violation -> privacy_scan.sh exits non-zero and
#      names the violation's location
#
# The planted violation is a throwaway working-tree file, created and removed
# by this script, containing only the placeholder pattern "ACME_CORP" from
# .privacy_patterns.example — never a real leak pattern, and never committed.
set -euo pipefail

VIOLATION_FILE="privacy_scan_selfcheck_violation.txt"
PATTERNS_FILE=".privacy_patterns"
PATTERNS_BACKUP=".privacy_patterns.selfcheck.bak"

cleanup() {
    rm -f "$VIOLATION_FILE"
    if [ -f "$PATTERNS_BACKUP" ]; then
        mv "$PATTERNS_BACKUP" "$PATTERNS_FILE"
    elif [ "$RESTORE_ABSENT" = "1" ]; then
        rm -f "$PATTERNS_FILE"
    fi
}
trap cleanup EXIT

RESTORE_ABSENT=0
if [ -f "$PATTERNS_FILE" ]; then
    mv "$PATTERNS_FILE" "$PATTERNS_BACKUP"
else
    RESTORE_ABSENT=1
fi
cp .privacy_patterns.example "$PATTERNS_FILE"

echo "== case 1: clean tree =="
if bash scripts/privacy_scan.sh; then
    echo "PASS: clean tree exits 0"
else
    echo "FAIL: clean tree did not exit 0"
    exit 1
fi

echo ""
echo "== case 2: planted violation =="
echo "ACME_CORP" > "$VIOLATION_FILE"

set +e
OUTPUT=$(bash scripts/privacy_scan.sh 2>&1)
STATUS=$?
set -e

echo "$OUTPUT"

if [ "$STATUS" -eq 0 ]; then
    echo "FAIL: planted violation did not cause a non-zero exit"
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "$VIOLATION_FILE"; then
    echo "FAIL: output did not name the violation's location ($VIOLATION_FILE)"
    exit 1
fi

echo "PASS: planted violation exits non-zero and names its location"
