#!/usr/bin/env bash
# task.sh — minimal kanban CLI for vibe coding
# Usage:
#   task.sh status [--json]
#   task.sh dump <milestone>
#   task.sh check <task-path>
#   task.sh reject <task-path> ["reason"]
#   task.sh new <milestone> <epic> "<title>" [--type T]
#   task.sh validate [milestone]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_DIR="${TASKS_DIR:-.tasks}"

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    echo "Install with: brew install jq  (macOS)  or  apt install jq  (Debian/Ubuntu)" >&2
    exit 1
fi

# Check tasks directory exists
if [ ! -d "$TASKS_DIR" ]; then
    echo "Error: $TASKS_DIR directory not found. Run from repo root." >&2
    exit 1
fi

CMD="${1:-}"

case "$CMD" in
    status)
        shift || true
        exec "$SCRIPT_DIR/status.sh" "$@"
        ;;
    dump)
        if [ -z "${2:-}" ]; then
            echo "Error: dump requires a milestone argument" >&2
            echo "Usage: task.sh dump <milestone>" >&2
            echo "Available milestones:" >&2
            ls -1 "$TASKS_DIR" 2>/dev/null | grep -E '^M[0-9]+-' >&2 || echo "  (none)" >&2
            exit 1
        fi
        exec "$SCRIPT_DIR/dump.sh" "$2"
        ;;
    check)
        if [ -z "${2:-}" ]; then
            echo "Error: check requires a task file path" >&2
            echo "Usage: task.sh check <path-to-task.md>" >&2
            exit 1
        fi
        exec "$SCRIPT_DIR/check.sh" "$2"
        ;;
    reject)
        if [ -z "${2:-}" ]; then
            echo "Error: reject requires a task file path" >&2
            echo "Usage: task.sh reject <path-to-task.md> [\"reason\"]" >&2
            exit 2
        fi
        shift || true
        exec "$SCRIPT_DIR/reject.sh" "$@"
        ;;
    new)
        shift || true
        exec "$SCRIPT_DIR/new.sh" "$@"
        ;;
    validate)
        shift || true
        exec "$SCRIPT_DIR/validate.sh" "$@"
        ;;
    ""|help|--help|-h)
        cat <<EOF
task.sh — minimal kanban CLI

Usage:
  task.sh status [--json]          Overview of all milestones (text, or JSON with --json)
  task.sh dump <milestone>         JSON dump of all tasks in a milestone
  task.sh check <task-path>        Verify a task is safe to close (all Actions+DoD [x],
                                   plus any 'run:' verification commands pass)
  task.sh reject <task-path> [why] Reviewer refuted the task: bump the rejection
                                   counter, send it back to in_progress for rework;
                                   STOPS the kanban (exit 3) past 2 rejections
  task.sh new <ms> <epic> "<t>"    Scaffold a new task file (use "-" for epic = no epic)
                                   [--type T] [--priority P] [--status S]
  task.sh validate [milestone]     Structural integrity check (ids, folders, references)

See the kanban skill's references/scripts.md for details.
EOF
        ;;
    *)
        echo "Error: unknown command '$CMD'" >&2
        echo "Run 'task.sh help' for usage." >&2
        exit 1
        ;;
esac
