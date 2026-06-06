#!/usr/bin/env bash
# status.sh — print overview of all milestones with task counts per status
# Usage:
#   status.sh           text overview (default)
#   status.sh --json    machine-readable JSON array
set -euo pipefail

TASKS_DIR="${TASKS_DIR:-.tasks}"

FORMAT="text"
if [ "${1:-}" = "--json" ]; then
    FORMAT="json"
fi

if [ "$FORMAT" = "json" ] && ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for --json output but is not installed." >&2
    exit 1
fi

# Extract a YAML field value from the front matter of a markdown file.
# Front matter is delimited by --- lines at the start of the file.
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

# Find all milestone folders (M<N>-*)
milestones=()
while IFS= read -r -d '' dir; do
    milestones+=("$(basename "$dir")")
done < <(find "$TASKS_DIR" -maxdepth 1 -type d -name 'M[0-9]*-*' -print0 | sort -z)

if [ ${#milestones[@]} -eq 0 ]; then
    if [ "$FORMAT" = "json" ]; then
        echo "[]"
    else
        echo "No milestones found in $TASKS_DIR/"
        echo "Create one with a folder like '$TASKS_DIR/M1-<slug>/'"
    fi
    exit 0
fi

json_out="[]"

for ms in "${milestones[@]}"; do
    declare -A counts=(
        [backlog]=0
        [todo]=0
        [in_progress]=0
        [blocked]=0
        [done]=0
        [cancelled]=0
    )
    total=0

    while IFS= read -r -d '' task; do
        status=$(get_field "$task" "status")
        [ -z "$status" ] && status="todo"
        if [ -n "${counts[$status]+x}" ]; then
            counts[$status]=$((counts[$status] + 1))
        fi
        total=$((total + 1))
    done < <(find "$TASKS_DIR/$ms" -type f -name 'TASK-*.md' -print0)

    if [ "$FORMAT" = "json" ]; then
        obj=$(jq -n \
            --arg milestone "$ms" \
            --argjson total "$total" \
            --argjson backlog "${counts[backlog]}" \
            --argjson todo "${counts[todo]}" \
            --argjson in_progress "${counts[in_progress]}" \
            --argjson blocked "${counts[blocked]}" \
            --argjson done "${counts[done]}" \
            --argjson cancelled "${counts[cancelled]}" \
            '{milestone: $milestone, total: $total,
              done: $done, in_progress: $in_progress, todo: $todo,
              blocked: $blocked, backlog: $backlog, cancelled: $cancelled}')
        json_out=$(echo "$json_out" | jq --argjson o "$obj" '. += [$o]')
    else
        printf "%-20s %3d tasks   %d done, %d in_progress, %d todo, %d blocked, %d backlog" \
            "$ms" "$total" \
            "${counts[done]}" "${counts[in_progress]}" "${counts[todo]}" "${counts[blocked]}" "${counts[backlog]}"

        if [ "${counts[cancelled]}" -gt 0 ]; then
            printf ", %d cancelled" "${counts[cancelled]}"
        fi
        echo
    fi

    unset counts
done

if [ "$FORMAT" = "json" ]; then
    echo "$json_out"
fi
