#!/usr/bin/env bash
#
# pre-commit-hook.sh — wrapper around check.sh in pre-commit mode.
#
# Install in your project with:
#
#   ln -sf ../../path/to/agile-team-v2/skills/agile-project/scripts/pre-commit-hook.sh .git/hooks/pre-commit
#
# Or copy if symlinks are not desirable on your platform.
#
# The wrapper exits non-zero on a blocking failure, which aborts the commit.
# Bypassing with `git commit --no-verify` is technically possible but is
# detected and blocked by the CI mode of check.sh on the sprint window
# (see R4 in the agile-project skill).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check.sh"

if [[ ! -x "$CHECK" ]]; then
    if [[ -f "$CHECK" ]]; then
        chmod +x "$CHECK"
    else
        echo "[pre-commit] check.sh not found at $CHECK" >&2
        exit 1
    fi
fi

exec "$CHECK" --mode pre-commit
