#!/usr/bin/env bash
# reject.sh — record a reviewer rejection and drive the rework loop.
# The reviewer calls this when the close audit refutes the task. It:
#   1. increments the `review_rejections` counter in the front matter
#   2. sends the task back to `status: in_progress` so a fixer agent reworks it
#   3. GUARD: once the counter exceeds MAX_REJECTS (default 2), i.e. on the 3rd
#      rejection, it refuses to keep looping — the task is set to
#      `status: blocked` and the kanban STOPS, escalating to the user.
# The reviewer still writes the findings into the task's ## Discussion (it has
# the date and the detail); this script only moves the mechanical state.
# Usage: reject.sh <task-path> ["reason"]
# Exit 0 = rework: task back to in_progress, fixer must address the review.
# Exit 3 = STOP: rejection limit exceeded, kanban halted, escalate to the user.
# Exit 2 = error.
set -euo pipefail

FILE="${1:-}"
REASON="${2:-}"
MAX_REJECTS="${MAX_REJECTS:-2}"

if [ -z "$FILE" ]; then
    echo "Error: task file path required" >&2
    echo "Usage: reject.sh <task-path> [\"reason\"]" >&2
    exit 2
fi
if [ ! -f "$FILE" ]; then
    echo "Error: file '$FILE' not found" >&2
    exit 2
fi

# Extract a YAML field value from front matter (same parser as check.sh).
get_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        BEGIN { in_fm = 0; count = 0 }
        /^---$/ {
            count++
            if (count == 1) { in_fm = 1; next }
            if (count == 2) { exit }
        }
        in_fm && $0 ~ "^"field":" {
            sub("^"field":[[:space:]]*", "")
            gsub(/^["'\'']/, "")
            gsub(/["'\'']$/, "")
            print
            exit
        }
    ' "$file"
}

ID=$(get_field "$FILE" "id")
CURRENT=$(get_field "$FILE" "review_rejections")
case "$CURRENT" in
    ''|*[!0-9]*) CURRENT=0 ;;
esac
NEW=$((CURRENT + 1))

if [ "$NEW" -gt "$MAX_REJECTS" ]; then
    NEW_STATUS="blocked"
else
    NEW_STATUS="in_progress"
fi

# Rewrite front matter: update `status`, set/insert `review_rejections`.
tmp="$(mktemp)"
awk -v new_status="$NEW_STATUS" -v rejections="$NEW" '
    BEGIN { in_fm = 0; count = 0; wrote_rej = 0 }
    /^---$/ {
        count++
        if (count == 2 && !wrote_rej) {
            print "review_rejections: " rejections
            wrote_rej = 1
        }
        print
        if (count == 1) { in_fm = 1 } else if (count == 2) { in_fm = 0 }
        next
    }
    in_fm && /^status:/ { print "status: " new_status; next }
    in_fm && /^review_rejections:/ { print "review_rejections: " rejections; wrote_rej = 1; next }
    { print }
' "$FILE" > "$tmp"
mv "$tmp" "$FILE"

echo "Task:       $ID"
echo "Rejections: $NEW (limit $MAX_REJECTS)"
echo

if [ "$NEW" -gt "$MAX_REJECTS" ]; then
    echo "STOP: task rejected $NEW times (> $MAX_REJECTS)."
    echo "Status set to 'blocked'. Halting the kanban — the rework loop is not"
    echo "converging. Escalate to the user: this needs a human decision, not"
    echo "another automated fix attempt."
    [ -n "$REASON" ] && echo "Last rejection reason: $REASON"
    exit 3
else
    echo "REWORK: rejection #$NEW recorded. Status set to 'in_progress'."
    echo "A fixer agent must now pick up the code + the reviewer's findings from"
    echo "## Discussion, fix them, get 'task.sh check' green, then hand back for"
    echo "re-review by a DIFFERENT agent than the fixer."
    [ -n "$REASON" ] && echo "Rejection reason: $REASON"
    exit 0
fi
