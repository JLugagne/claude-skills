#!/usr/bin/env bash
#
# check.sh — agile-team-v2 workflow gate.
#
# Two modes:
#   --mode pre-commit   Fast, marker-and-format checks. Bypassable with --no-verify.
#   --mode ci           Full audit. No bypass.
#
# CI mode runs everything pre-commit checks plus heavier git-history audits.
#
# The script returns 0 if all checks pass, 1 if any blocking check fails.
# A blocking failure prints a "BLOCK:" line with a path:line reference where applicable.
#
# Conventions enforced (mirrors the agile-project SKILL.md):
#
#   AC marker:       // AC: <description>
#                    // TODO(impl-<feat-slug>, ac-<NNN>)
#                    panic("not implemented")
#
#   SCENARIO marker: // SCENARIO: <narrative>
#                    // TODO(impl-<feat-slug>, scenario-<NNN>)
#                    t.Skip("not implemented")
#
#   Authored-By trailer: required on commits touching .decisions/ or modifying
#                        the `mechanical:` field of any FEATURE.md.
#
#   pm_test_territories: glob list declared in .architecture/CONVENTIONS.md.
#                        Used to scope SCENARIO markers (must live inside).
#
# Exit codes:
#   0  all checks pass
#   1  blocking failure
#   2  usage error

set -u
set -o pipefail

MODE="${1:-}"
shift || true

if [[ "$MODE" != "--mode" || "${1:-}" == "" ]]; then
    echo "usage: check.sh --mode <pre-commit|ci>" >&2
    exit 2
fi

MODE="$1"
shift || true

if [[ "$MODE" != "pre-commit" && "$MODE" != "ci" ]]; then
    echo "BLOCK: unknown mode '$MODE' (expected pre-commit | ci)" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FAILURES=0

fail() {
    # fail "<message>"
    echo "BLOCK: $1" >&2
    FAILURES=$((FAILURES + 1))
}

note() {
    echo "[check.sh] $1"
}

# Find the repo root. We assume we run from somewhere inside it.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    echo "BLOCK: not inside a git repository" >&2
    exit 1
fi
cd "$REPO_ROOT"

# Read pm_test_territories from .architecture/CONVENTIONS.md if present.
# Format expected (yaml-ish block):
#   pm_test_territories:
#     - tests/e2e-api/
#     - "**/usecase/*_test.go"
PM_TERRITORIES=()
if [[ -f .architecture/CONVENTIONS.md ]]; then
    in_block=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^pm_test_territories: ]]; then
            in_block=1
            continue
        fi
        if [[ $in_block -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\"?([^\"]+)\"?[[:space:]]*$ ]]; then
                PM_TERRITORIES+=("${BASH_REMATCH[1]}")
            elif [[ "$line" =~ ^[^[:space:]] ]]; then
                in_block=0
            fi
        fi
    done < .architecture/CONVENTIONS.md
fi

# Test if a path matches any pm_test_territory glob.
path_in_pm_territories() {
    local path="$1"
    if [[ ${#PM_TERRITORIES[@]} -eq 0 ]]; then
        return 1
    fi
    for glob in "${PM_TERRITORIES[@]}"; do
        # bash extglob doesn't natively grok ** — translate manually.
        case "$path" in
            $glob) return 0 ;;
        esac
        # If the territory ends with /, treat as prefix match.
        if [[ "$glob" == */ && "$path" == "$glob"* ]]; then
            return 0
        fi
        # If the territory contains **, do a permissive prefix+suffix match.
        if [[ "$glob" == *"**"* ]]; then
            local prefix="${glob%%\*\**}"
            local suffix="${glob##*\*\*}"
            # Strip leading slash from suffix.
            suffix="${suffix#/}"
            if [[ "$path" == "$prefix"*"$suffix" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Pre-commit checks (always run)
# ---------------------------------------------------------------------------

note "running pre-commit checks (mode=$MODE)"

# 1. golangci-lint, go test, go build, go vet (only at CI mode — pre-commit
# is supposed to be fast; users wire their own scoped linter on staged files).
if [[ "$MODE" == "ci" ]]; then
    if command -v golangci-lint >/dev/null 2>&1; then
        if ! golangci-lint run ./... ; then
            fail "golangci-lint failed"
        fi
    else
        note "golangci-lint not installed; skipping"
    fi

    if ! go build ./...; then
        fail "go build ./... failed"
    fi
    if ! go vet ./...; then
        fail "go vet ./... failed"
    fi
    if ! go test ./...; then
        fail "go test ./... failed"
    fi
fi

# 2. Marker linting — `// SCENARIO:` outside pm_test_territories.
note "checking SCENARIO markers stay inside pm_test_territories"
while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    if ! path_in_pm_territories "$file"; then
        fail "SCENARIO outside pm_test_territories: $file:$line"
    fi
done < <(grep -rn '^[[:space:]]*//[[:space:]]*SCENARIO:' --include='*.go' . 2>/dev/null || true)

# 3. Marker linting — TODO(impl-...) malformed.
note "checking TODO(impl-...) marker format"
while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    text="${rest#*:}"
    if [[ ! "$text" =~ TODO\(impl-[a-z][a-z0-9-]*,[[:space:]]*(ac|scenario)-[0-9]{3}\) ]]; then
        fail "malformed TODO(impl-...) marker: $file:$line"
    fi
done < <(grep -rn 'TODO(impl-' --include='*.go' . 2>/dev/null || true)

# 4. DECISIONS green — must have scope: tactical and review.revisit: true.
note "checking .decisions/ format"
if [[ -d .decisions ]]; then
    for decision in .decisions/DECISION-*.md; do
        [[ -f "$decision" ]] || continue
        # Read frontmatter (between the first two --- lines).
        fm=$(awk '/^---/{n++; next} n==1 {print} n==2 {exit}' "$decision")

        author=$(echo "$fm" | grep -E '^author:' | head -1 | awk '{print $2}')
        scope=$(echo "$fm" | grep -E '^scope:' | head -1 | awk '{print $2}')
        revisit=$(echo "$fm" | grep -E '^[[:space:]]+revisit:' | head -1 | awk '{print $2}')
        reviewed_by=$(echo "$fm" | grep -E '^[[:space:]]+reviewed_by:' | head -1 | awk '{print $2}')
        reviewed_at=$(echo "$fm" | grep -E '^[[:space:]]+reviewed_at:' | head -1 | awk '{print $2}')
        outcome=$(echo "$fm" | grep -E '^[[:space:]]+outcome:' | head -1 | awk '{print $2}')

        if [[ "$author" == "green" ]]; then
            if [[ "$scope" != "tactical" ]]; then
                fail "DECISION authored by green must have scope: tactical: $decision"
            fi
            # Initial creation: revisit must be true (only enforced when reviewed_by is null,
            # i.e., not yet statued).
            if [[ "$reviewed_by" == "null" ]]; then
                if [[ "$revisit" != "true" ]]; then
                    fail "DECISION authored by green with reviewed_by: null must have revisit: true: $decision"
                fi
            fi
            if [[ "$scope" == "strategic" ]]; then
                fail "DECISION authored by green cannot be scope: strategic (architect only): $decision"
            fi
        fi

        # Zone review must always have all four fields, even if null.
        for field in revisit reviewed_by reviewed_at outcome; do
            if ! echo "$fm" | grep -qE "^[[:space:]]+${field}:"; then
                fail "DECISION missing review.${field}: $decision"
            fi
        done
    done
fi

# 5. REVIEW.md `## Human override` format (5 strict fields).
note "checking REVIEW.md ## Human override format"
while IFS= read -r review; do
    [[ -f "$review" ]] || continue
    # Extract everything after "## Human override".
    awk '/^## Human override/{p=1; next} p' "$review" > /tmp/check_override.$$
    if [[ -s /tmp/check_override.$$ ]]; then
        # For each "### Override" block, verify 5 fields.
        awk -v file="$review" '
            /^### Override/ {
                if (block_count) {
                    if (!(has_finding && has_reason && has_dref && has_date && has_author)) {
                        printf("BLOCK: malformed ## Human override block in %s: missing fields\n", file) > "/dev/stderr"
                        bad++
                    }
                }
                block_count++
                has_finding=has_reason=has_dref=has_date=has_author=0
                next
            }
            /^- \*\*Finding overridden:\*\*/ { has_finding=1 }
            /^- \*\*Reason:\*\*/ { has_reason=1 }
            /^- \*\*Decision reference:\*\*/ { has_dref=1 }
            /^- \*\*Date:\*\*/ { has_date=1 }
            /^- \*\*Author:\*\*/ { has_author=1 }
            END {
                if (block_count) {
                    if (!(has_finding && has_reason && has_dref && has_date && has_author)) {
                        printf("BLOCK: malformed ## Human override block in %s: missing fields\n", file) > "/dev/stderr"
                        bad++
                    }
                }
                exit (bad ? 1 : 0)
            }
        ' /tmp/check_override.$$ || FAILURES=$((FAILURES + 1))
    fi
    rm -f /tmp/check_override.$$
done < <(find . -path ./.git -prune -o -name 'REVIEW.md' -print 2>/dev/null)

# 6. Override on a security finding without `Decision reference: DECISION-NNN`.
# Heuristic: an override block whose "Finding overridden" mentions Pass 3 / Security
# must have a non-null "Decision reference".
note "checking that security overrides reference a DECISION"
while IFS= read -r review; do
    [[ -f "$review" ]] || continue
    awk '
        /^### Override/ {
            if (in_block && security && (dref == "" || dref == "null" || dref == "<DECISION-NNN | null>")) {
                printf("BLOCK: security override without Decision reference in %s\n", FILENAME) > "/dev/stderr"
            }
            in_block=1; security=0; dref=""
            next
        }
        /^- \*\*Finding overridden:\*\*.*[Pp]ass 3|[Ss]ecurity|IDOR|SSRF|injection|authz/ {
            security=1
        }
        /^- \*\*Decision reference:\*\*/ {
            sub(/^- \*\*Decision reference:\*\*[[:space:]]*/, "")
            dref=$0
        }
        END {
            if (in_block && security && (dref == "" || dref == "null" || dref == "<DECISION-NNN | null>")) {
                printf("BLOCK: security override without Decision reference in %s\n", FILENAME) > "/dev/stderr"
                exit 1
            }
        }
    ' "$review" || FAILURES=$((FAILURES + 1))
done < <(find . -path ./.git -prune -o -name 'REVIEW.md' -print 2>/dev/null)

# 7. Authored-By trailer cross-check on .decisions/ and FEATURE.md `mechanical:`.
# Pre-commit: only the staged diff. CI: every commit on the sprint window (heuristic =
# every commit reachable from HEAD that is not on origin/main).
note "checking Authored-By trailer on .decisions/ and mechanical: changes"
range=""
if [[ "$MODE" == "ci" ]]; then
    # Default range: HEAD..origin/main if the remote exists, else last 50 commits
    # if the repo has at least 50 commits, else all of HEAD's history.
    if git rev-parse origin/main >/dev/null 2>&1; then
        range="origin/main..HEAD"
    elif git rev-parse HEAD~50 >/dev/null 2>&1; then
        range="HEAD~50..HEAD"
    elif git rev-parse HEAD >/dev/null 2>&1; then
        range="HEAD"
    else
        # Empty repo, no commits yet — nothing to audit.
        range=""
    fi
elif [[ "$MODE" == "pre-commit" ]]; then
    # Inspect the staged diff against HEAD.
    range="HEAD"
fi

if [[ "$MODE" == "ci" && -n "$range" ]]; then
    while IFS= read -r commit; do
        [[ -z "$commit" ]] && continue
        msg=$(git log -1 --format=%B "$commit")
        files=$(git diff-tree --no-commit-id --name-only -r "$commit")

        touches_decisions=0
        touches_mechanical=0

        if echo "$files" | grep -qE '^\.decisions/'; then
            touches_decisions=1
        fi
        if echo "$files" | grep -qE 'FEATURE\.md$'; then
            # Look in the diff body for a frontmatter `mechanical:` line change.
            if git show "$commit" -- '*FEATURE.md' | grep -qE '^[+-]mechanical:'; then
                touches_mechanical=1
            fi
        fi

        if [[ $touches_decisions -eq 1 || $touches_mechanical -eq 1 ]]; then
            authored_by=$(echo "$msg" | grep -E '^Authored-By:' | head -1 | awk '{print $2}')
            if [[ -z "$authored_by" ]]; then
                fail "commit $commit touches .decisions/ or mechanical: but lacks Authored-By trailer"
                continue
            fi
            # mechanical: must be Authored-By: architect.
            if [[ $touches_mechanical -eq 1 && "$authored_by" != "architect" ]]; then
                fail "commit $commit modifies mechanical: but Authored-By is '$authored_by' (must be architect)"
            fi
            # review.reviewed_by changes must be Authored-By: architect.
            if [[ $touches_decisions -eq 1 ]]; then
                if git show "$commit" -- '.decisions/*' | grep -qE '^\+[[:space:]]+reviewed_by:'; then
                    if [[ "$authored_by" != "architect" ]]; then
                        fail "commit $commit modifies review.reviewed_by but Authored-By is '$authored_by' (must be architect)"
                    fi
                fi
            fi
        fi
    done < <(git rev-list "$range" 2>/dev/null || echo "")
fi

# 8. Detect --no-verify on the sprint window (CI mode only).
# Heuristic: pre-commit hook leaves a marker line in commits it processed.
# Without that marker, the commit may have bypassed the hook. We look for
# explicit --no-verify hints in the message body or absence of expected hook signatures.
if [[ "$MODE" == "ci" && -n "$range" ]]; then
    note "checking for --no-verify commits on sprint window"
    while IFS= read -r commit; do
        [[ -z "$commit" ]] && continue
        msg=$(git log -1 --format=%B "$commit")
        if echo "$msg" | grep -qiE '(--no-verify|skip[- ]hook|bypass[- ]hook)'; then
            fail "commit $commit references --no-verify in message"
        fi
    done < <(git rev-list "$range" 2>/dev/null || echo "")
fi

# ---------------------------------------------------------------------------
# CI-only checks
# ---------------------------------------------------------------------------

if [[ "$MODE" == "ci" ]]; then
    # 9. Unresolved TODO(impl-...) on a feature whose status is `done` in INDEX.md.
    note "checking TODO(impl-...) resolution on done features"
    if [[ -f .features/INDEX.md ]]; then
        # Parse done features (lines like: | <slug> | done | ... |).
        while IFS= read -r row; do
            slug=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $2); print $2}')
            status=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $3); print $3}')
            if [[ "$status" == "done" && -n "$slug" ]]; then
                if grep -rn "TODO(impl-${slug}," --include='*.go' . 2>/dev/null | head -1 | grep -q .; then
                    leftover=$(grep -rn "TODO(impl-${slug}," --include='*.go' . 2>/dev/null | head -1)
                    fail "feature $slug is done in INDEX.md but unresolved TODO(impl-) remains: $leftover"
                fi
            fi
        done < <(grep -E '^\|' .features/INDEX.md 2>/dev/null || true)
    fi

    # 10. Unstatued tactical DECISIONS after the sprint of creation.
    # Heuristic: any DECISION with author: green, review.reviewed_by: null,
    # whose creation commit is older than one sprint window — block.
    # Implementation simplification: we just block any unstatued green DECISION on CI.
    # The architect statues at the start of the next sprint per R2; if it's still
    # null after a sprint completion, that's the violation.
    note "checking that previous sprint's tactical DECISIONS are statued"
    if [[ -d .decisions ]]; then
        for decision in .decisions/DECISION-*.md; do
            [[ -f "$decision" ]] || continue
            fm=$(awk '/^---/{n++; next} n==1 {print} n==2 {exit}' "$decision")
            author=$(echo "$fm" | grep -E '^author:' | head -1 | awk '{print $2}')
            reviewed_by=$(echo "$fm" | grep -E '^[[:space:]]+reviewed_by:' | head -1 | awk '{print $2}')
            if [[ "$author" == "green" && "$reviewed_by" == "null" ]]; then
                # Find the commit that introduced the file. If older than ~14 days, complain.
                first_commit=$(git log --diff-filter=A --format=%H --follow -- "$decision" 2>/dev/null | tail -1)
                if [[ -n "$first_commit" ]]; then
                    age_days=$(( ($(date +%s) - $(git log -1 --format=%ct "$first_commit")) / 86400 ))
                    if [[ $age_days -gt 14 ]]; then
                        fail "tactical DECISION $decision authored ${age_days}d ago by green is not yet statued (architect must reviewed_by/outcome)"
                    fi
                fi
            fi
        done
    fi

    # 11. INDEX.md ↔ reality coherence.
    note "checking .features/INDEX.md coherence with code state"
    if [[ -f .features/INDEX.md ]]; then
        while IFS= read -r row; do
            slug=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $2); print $2}')
            status=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $3); print $3}')
            [[ -z "$slug" ]] && continue

            case "$status" in
                ready)
                    # Must have at least one TODO(impl-<slug>, ac-) in code (scaffolded).
                    if ! grep -rn "TODO(impl-${slug}," --include='*.go' . >/dev/null 2>&1; then
                        # mechanical:true features may have only structural code, no AC markers.
                        # Check FEATURE.md mechanical flag.
                        if [[ -f ".features/${slug}/FEATURE.md" ]]; then
                            mechanical=$(grep -E '^mechanical:' ".features/${slug}/FEATURE.md" | awk '{print $2}')
                            if [[ "$mechanical" != "true" ]]; then
                                fail "feature $slug is ready but no TODO(impl-) markers found (scaffolding missing?)"
                            fi
                        fi
                    fi
                    ;;
                in-progress)
                    # Some SPRINT.md somewhere should mention it.
                    if ! grep -rn "impl-${slug}" .sprints/ >/dev/null 2>&1; then
                        fail "feature $slug is in-progress but no active SPRINT.md mentions it"
                    fi
                    ;;
                done)
                    # Already checked in #9 (no leftover TODO).
                    ;;
            esac
        done < <(grep -E '^\|' .features/INDEX.md 2>/dev/null || true)
    fi

    # 12. mechanical: flag presence on features at status >= scaffolded.
    note "checking mechanical: flag presence on scaffolded+ features"
    if [[ -f .features/INDEX.md ]]; then
        while IFS= read -r row; do
            slug=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $2); print $2}')
            status=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/, "", $3); print $3}')
            [[ -z "$slug" ]] && continue

            case "$status" in
                scaffolded|ready|in-progress|done)
                    if [[ ! -f ".features/${slug}/FEATURE.md" ]]; then
                        fail "feature $slug is $status but FEATURE.md missing"
                        continue
                    fi
                    if ! grep -qE '^mechanical:' ".features/${slug}/FEATURE.md"; then
                        fail "feature $slug is $status but mechanical: flag missing in FEATURE.md frontmatter"
                    fi
                    # If mechanical: true, mechanical_rationale: must be present.
                    mechanical=$(grep -E '^mechanical:' ".features/${slug}/FEATURE.md" | head -1 | awk '{print $2}')
                    if [[ "$mechanical" == "true" ]]; then
                        if ! grep -qE '^mechanical_rationale:' ".features/${slug}/FEATURE.md"; then
                            fail "feature $slug has mechanical: true but mechanical_rationale: missing"
                        fi
                    fi
                    ;;
            esac
        done < <(grep -E '^\|' .features/INDEX.md 2>/dev/null || true)
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $FAILURES -eq 0 ]]; then
    note "all checks passed (mode=$MODE)"
    exit 0
else
    note "$FAILURES blocking failure(s) (mode=$MODE)"
    exit 1
fi
