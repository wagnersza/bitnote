#!/bin/bash
# Usage: bash scripts/privacy_scan.sh
#
# Gate the owner runs before any publish. Exits non-zero, with one line per
# finding, if a privacy leak (or the evidence-tracking regression) is present.
#
# Secret literals (employer name, email domains) live in a gitignored
# .privacy_patterns file, never in this script, because this script is
# itself published. See .privacy_patterns.example for the format.
#
# History note: the working-tree home-path/username check is NOT repeated
# against full history. This repo's pre-cleanup commits and old feature
# branches still carry the old $HOME path (see issue #46/#51) and are staying
# in the private archive rather than being rewritten — so a history-wide
# home-path check could never pass here. Employer name, email domains, and
# credential-shaped strings ARE checked across all of history, since #46's
# audit found those clean throughout.
set -euo pipefail

FINDINGS=0

report() {
    echo "$1"
    FINDINGS=$((FINDINGS + 1))
}

CREDENTIAL_REGEX='(AKIA[0-9A-Z]{16})|((api|secret|access|auth)[_-]?)?(key|token|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/+_.=-]{16,}|(-----BEGIN[A-Z ]*PRIVATE KEY-----)'

PATTERNS_FILE=".privacy_patterns"
CUSTOM_PATTERNS=()
if [ -f "$PATTERNS_FILE" ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        CUSTOM_PATTERNS+=("$line")
    done < "$PATTERNS_FILE"
    if [ "${#CUSTOM_PATTERNS[@]}" -eq 0 ]; then
        echo "SKIP: $PATTERNS_FILE has no active patterns"
    fi
else
    echo "SKIP: $PATTERNS_FILE not found — employer/email-domain checks skipped (see .privacy_patterns.example)"
fi

echo "Scanning working tree..."

while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    report "WORKTREE ${hit%%:*} home directory path"
done < <(git grep --untracked -n -I -F -- "$HOME" -- . 2>/dev/null || true)

while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    report "WORKTREE ${hit%%:*} username"
done < <(git grep --untracked -n -I -F -- "$USER" -- . 2>/dev/null || true)

while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    report "WORKTREE ${hit%%:*} credential-shaped string"
done < <(git grep --untracked -n -I -E -- "$CREDENTIAL_REGEX" -- . ':!scripts/privacy_scan.sh' 2>/dev/null || true)

for pattern in "${CUSTOM_PATTERNS[@]+"${CUSTOM_PATTERNS[@]}"}"; do
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        report "WORKTREE ${hit%%:*} matches configured pattern"
    done < <(git grep --untracked -n -I -F -- "$pattern" -- . ':!.privacy_patterns.example' ':!scripts/privacy_scan_selfcheck.sh' 2>/dev/null || true)
done

echo "Scanning full commit history across every ref..."

ALL_REVS=()
while IFS= read -r rev; do
    ALL_REVS+=("$rev")
done < <(git rev-list --all)

while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    report "HISTORY ${hit%%:*} credential-shaped string"
done < <(git grep -n -I -E -- "$CREDENTIAL_REGEX" "${ALL_REVS[@]}" -- . 2>/dev/null || true)

for pattern in "${CUSTOM_PATTERNS[@]+"${CUSTOM_PATTERNS[@]}"}"; do
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        report "HISTORY ${hit%%:*} matches configured pattern"
    done < <(git grep -n -I -F -- "$pattern" "${ALL_REVS[@]}" -- . ':!.privacy_patterns.example' ':!scripts/privacy_scan_selfcheck.sh' 2>/dev/null || true)
done

echo "Checking docs/review/ is not tracked..."

TRACKED_REVIEW=$(git ls-files docs/review/ || true)
if [ -n "$TRACKED_REVIEW" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        report "TRACKED $f: docs/review/ must not be tracked"
    done <<< "$TRACKED_REVIEW"
fi

echo ""
if [ "$FINDINGS" -gt 0 ]; then
    echo "FAIL: $FINDINGS finding(s)"
    exit 1
fi

echo "PASS: no findings"
