#!/usr/bin/env bash
# new.sh — scaffold a new task file with valid front matter and empty sections.
# Usage:
#   new.sh <milestone> <epic> "<title>" [--type T] [--priority P] [--status S]
#
# Use "-" for <epic> to place the task directly under the milestone (no epic
# folder) — appropriate for standalone chore/bugfix work that doesn't belong to
# an epic. The ID is allocated from .tasks/.next-id and written back.
set -euo pipefail

TASKS_DIR="${TASKS_DIR:-.tasks}"

TYPE="feature"
PRIORITY="normal"
STATUS="todo"
positional=()

while [ $# -gt 0 ]; do
    case "$1" in
        --type)     TYPE="${2:-}"; shift 2 ;;
        --priority) PRIORITY="${2:-}"; shift 2 ;;
        --status)   STATUS="${2:-}"; shift 2 ;;
        *)          positional+=("$1"); shift ;;
    esac
done

if [ ${#positional[@]} -lt 3 ]; then
    echo "Error: new requires <milestone> <epic> \"<title>\"" >&2
    echo "Usage: task.sh new <milestone> <epic> \"<title>\" [--type T] [--priority P] [--status S]" >&2
    echo "       use \"-\" for <epic> to put the task directly under the milestone" >&2
    exit 1
fi

MS="${positional[0]}"
EPIC="${positional[1]}"
TITLE="${positional[2]}"

MS_DIR="$TASKS_DIR/$MS"
if [ ! -d "$MS_DIR" ]; then
    echo "Error: milestone folder '$MS_DIR' not found." >&2
    echo "Create the milestone (with a PRD.md) first — see references/milestone-planning.md." >&2
    exit 1
fi

# Resolve target directory and the epic front-matter value.
if [ "$EPIC" = "-" ] || [ "$EPIC" = "." ] || [ -z "$EPIC" ]; then
    TARGET_DIR="$MS_DIR"
    EPIC_FIELD=""
else
    TARGET_DIR="$MS_DIR/$EPIC"
    EPIC_FIELD="$EPIC"
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Note: epic folder '$TARGET_DIR' did not exist — creating it." >&2
        mkdir -p "$TARGET_DIR"
    fi
    if [ ! -f "$TARGET_DIR/doc.md" ]; then
        echo "Warning: '$TARGET_DIR/doc.md' is missing. Add an epic brief (see references/structure.md)." >&2
    fi
fi

# Allocate the next task ID.
NEXT_ID_FILE="$TASKS_DIR/.next-id"
last=0
if [ -f "$NEXT_ID_FILE" ]; then
    last=$(tr -d '[:space:]' < "$NEXT_ID_FILE")
    [ -z "$last" ] && last=0
fi
n=$((last + 1))
ID=$(printf "TASK-%03d" "$n")
FILE="$TARGET_DIR/$ID.md"

if [ -e "$FILE" ]; then
    echo "Error: '$FILE' already exists. Aborting to avoid overwrite." >&2
    exit 1
fi

cat > "$FILE" <<EOF
---
id: $ID
title: $TITLE
description: ""
milestone: $MS
epic: $EPIC_FIELD
status: $STATUS
priority: $PRIORITY
type: $TYPE
blocked_by: []
branch: ""
review_rejections: 0
---

## Actions

## Definition of Done

## Discussion
EOF

# Persist the new high-water mark.
echo "$n" > "$NEXT_ID_FILE"

echo "Created $FILE"
echo "  id: $ID  type: $TYPE  status: $STATUS  priority: $PRIORITY"
echo "Next: fill description, draft DoD then Actions (see references/working-on-task.md)."
