#!/bin/bash
# Requires Xcode toolchain — CommandLineTools lacks XCTest.
# Usage: bash scripts/coverage.sh
set -euo pipefail

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --enable-code-coverage 2>&1

PROFDATA=$(find .build -name "default.profdata" | head -1)
if [ -z "$PROFDATA" ]; then
    echo "ERROR: no .profdata found" >&2
    exit 1
fi

BINARY=$(find .build -name "BitnotePackageTests" -path "*/MacOS/BitnotePackageTests" | grep -v dSYM | head -1)
if [ -z "$BINARY" ]; then
    echo "ERROR: test binary not found" >&2
    exit 1
fi

XCRUN_LLVM_COV="$(xcrun --find llvm-cov)"

"$XCRUN_LLVM_COV" report "$BINARY" \
    -instr-profile="$PROFDATA" \
    -sources Sources/BitnoteCore/

COVERAGE=$("$XCRUN_LLVM_COV" report "$BINARY" \
    -instr-profile="$PROFDATA" \
    -sources Sources/BitnoteCore/ 2>/dev/null \
    | grep TOTAL | awk '{print $NF}' | tr -d '%')

echo ""
echo "BitnoteCore line coverage: ${COVERAGE}%"

if (( $(echo "$COVERAGE < 90" | bc -l) )); then
    echo "FAIL: coverage ${COVERAGE}% is below 90% gate" >&2
    exit 1
fi

echo "PASS: coverage gate >= 90%"
