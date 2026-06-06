#!/usr/bin/env bash
# validate.sh — structural integrity check over the whole board (or one milestone).
# Verifies, for every TASK-*.md:
#   - filename matches the `id` field
#   - `milestone` field matches the enclosing milestone folder
#   - `epic` field matches the parent folder (empty if directly under milestone)
#   - every id in `blocked_by` refers to a task that exists
#   - every id in `verifies` refers to a task that exists
#   - epics that contain tasks also contain a doc.md
#   - every milestone contains a PRD.md
# Usage:
#   validate.sh [milestone]
# Exit 0 = no problems; exit 1 = problems found; exit 2 = error.
set -euo pipefail

TASKS_DIR="${TASKS_DIR:-.tasks}"
SCOPE="${1:-}"

if [ ! -d "$TASKS_DIR" ]; then
    echo "Error: $TASKS_DIR directory not found. Run from repo root." >&2
    exit 2
fi

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

# Print the ids inside a YAML inline list field (e.g. blocked_by: [TASK-001, TASK-002]).
get_id_list() {
    local file="$1"
    local field="$2"
    local raw
    raw=$(get_field "$file" "$field")
    raw="${raw#[}"
    raw="${raw%]}"
    [ -z "$raw" ] && return
    echo "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true
}

# Determine the search root.
if [ -n "$SCOPE" ]; then
    if [ ! -d "$TASKS_DIR/$SCOPE" ]; then
        echo "Error: milestone folder '$TASKS_DIR/$SCOPE' not found" >&2
        exit 2
    fi
    ROOT="$TASKS_DIR/$SCOPE"
else
    ROOT="$TASKS_DIR"
fi

# First pass: collect every known task id across the WHOLE board (cross-milestone
# dependencies are legal, so blocked_by/verifies must resolve against everything).
declare -A known_ids=()
while IFS= read -r -d '' f; do
    fid=$(get_field "$f" "id")
    [ -n "$fid" ] && known_ids["$fid"]=1
done < <(find "$TASKS_DIR" -type f -name 'TASK-*.md' -print0)

problems=()
checked=0

# Second pass: validate each task in scope.
while IFS= read -r -d '' f; do
    checked=$((checked + 1))
    base=$(basename "$f" .md)
    parent=$(basename "$(dirname "$f")")
    grandparent=$(basename "$(dirname "$(dirname "$f")")")

    id=$(get_field "$f" "id")
    ms=$(get_field "$f" "milestone")
    epic=$(get_field "$f" "epic")

    # filename vs id
    if [ "$id" != "$base" ]; then
        problems+=("$f: id '$id' does not match filename '$base'")
    fi

    # Is the task directly under a milestone folder (no epic) or inside an epic?
    if [[ "$parent" =~ ^M[0-9]+- ]]; then
        # Directly under milestone: parent is the milestone, epic should be empty.
        if [ "$ms" != "$parent" ]; then
            problems+=("$f: milestone '$ms' does not match folder '$parent'")
        fi
        if [ -n "$epic" ]; then
            problems+=("$f: epic '$epic' set but task is directly under milestone (expected empty)")
        fi
    else
        # Inside an epic: parent is the epic, grandparent the milestone.
        if [ "$epic" != "$parent" ]; then
            problems+=("$f: epic '$epic' does not match folder '$parent'")
        fi
        if [ "$ms" != "$grandparent" ]; then
            problems+=("$f: milestone '$ms' does not match folder '$grandparent'")
        fi
    fi

    # blocked_by / verifies references must exist
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        if [ -z "${known_ids[$ref]+x}" ]; then
            problems+=("$f: blocked_by references unknown task '$ref'")
        fi
    done < <(get_id_list "$f" "blocked_by")

    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        if [ -z "${known_ids[$ref]+x}" ]; then
            problems+=("$f: verifies references unknown task '$ref'")
        fi
    done < <(get_id_list "$f" "verifies")
done < <(find "$ROOT" -type f -name 'TASK-*.md' -print0)

# Structural checks: epic folders with tasks need a doc.md; milestones need a PRD.md.
while IFS= read -r -d '' dir; do
    # Does this directory directly contain any task files?
    if compgen -G "$dir/TASK-*.md" >/dev/null; then
        parent=$(basename "$dir")
        # Skip milestone-level (those are not epics).
        if [[ ! "$parent" =~ ^M[0-9]+- ]]; then
            [ -f "$dir/doc.md" ] || problems+=("$dir: epic folder has tasks but no doc.md")
        fi
    fi
done < <(find "$ROOT" -type d -print0)

if [ -n "$SCOPE" ]; then
    [ -f "$TASKS_DIR/$SCOPE/PRD.md" ] || problems+=("$TASKS_DIR/$SCOPE: milestone folder has no PRD.md")
else
    while IFS= read -r -d '' msdir; do
        [ -f "$msdir/PRD.md" ] || problems+=("$msdir: milestone folder has no PRD.md")
    done < <(find "$TASKS_DIR" -maxdepth 1 -type d -name 'M[0-9]*-*' -print0)
fi

echo "Validated $checked task file(s)."
echo

if [ ${#problems[@]} -eq 0 ]; then
    echo "OK: no structural problems found"
    exit 0
else
    echo "PROBLEMS (${#problems[@]}):"
    for p in "${problems[@]}"; do
        echo "  - $p"
    done
    exit 1
fi
