---
description: "Use when a feature pipeline is fully complete — all tasks green, all reviews passed, acceptance criteria met. Guides final verification, cleanup of .plan/ artifacts, and branch integration (merge, PR, or keep)."
---

# Go Finish

Guide completion of a feature after the full pipeline has run. Verify everything, clean up, and integrate.

## The Process

### Step 1: Final Verification

**Before presenting options, run the full verification suite:**

```bash
# Build
go build ./...

# Full test suite with race detection
go test ./... -count=1 -race

# Check for any skipped tests (leftover TODOs from scaffolding)
go test ./... -count=1 -v 2>&1 | grep -c "SKIP"
```

**If anything fails:** Stop. Do not proceed. Report the failure and suggest whether go-fixer or go-debugger is appropriate.

**If skipped tests remain:** These are unimplemented test stubs from scaffolding. Either they were intentionally deferred (user decision) or they were missed. Ask the user.

### Step 2: Acceptance Criteria Check

Read `.plan/<feature-slug>/FEATURE.md` and check every item in "Definition of Done":

```
## Acceptance Criteria Verification

- [x] All tests pass (go test ./... — evidence above)
- [x] Project compiles (go build ./... — evidence above)
- [x] E2E tests cover happy path and error cases (TestXxx_E2E_*)
- [x] Security tests cover IDOR and validation (TestXxx_WrongProject_*)
- [ ] Database migrations are idempotent (NEEDS VERIFICATION)
...
```

For each item: either point to evidence (test name, command output) or flag it as unverified.

### Step 3: Review Summary Report

Read all `.plan/<feature-slug>/task-*_SUMMARY.md` files and `.plan/<feature-slug>/task-rev-*` (reviewer task files) to produce a concise report:

```
## Feature Summary: <feature-slug>

### What was built
[2-3 sentences]

### Files created/modified
[List from task summaries — deduplicated]

### Review findings addressed
[From go-reviewer tasks — what was caught and fixed]

### Open items (if any)
[Anything deferred or flagged during the pipeline]
```

### Step 4: Plan Artifacts Cleanup

Ask: "Should I archive the .plan/<feature-slug>/ directory?"

- **Archive** (recommended): move to `.plan/done/<feature-slug>/` — preserves history
- **Delete**: remove `.plan/<feature-slug>/` entirely
- **Keep**: leave as-is (useful if more work is expected)

### Step 5: Present Integration Options

```
Feature complete and verified. What would you like to do?

1. Merge to main/master locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work
```

### Step 6: Execute Choice

#### Option 1: Merge Locally
```bash
git checkout main
git pull
git merge <feature-branch>
# Re-run tests on merged result
go test ./... -count=1 -race
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR
```bash
git push -u origin <feature-branch>
gh pr create --title "feat: <feature-slug>" --body "$(cat <<'EOF'
## Summary
[From Step 3 report]

## Test Plan
- All unit, contract, and e2e tests pass with -race
- Acceptance criteria verified against FEATURE.md
- go-reviewer findings addressed

## Review Notes
[From go-reviewer report]
EOF
)"
```

#### Option 3: Keep As-Is
Report: "Branch preserved. Plan artifacts at `.plan/<feature-slug>/`."

#### Option 4: Discard
**Require typed confirmation:**
```
This will permanently delete:
- Branch: <name>
- Commits: <list>
- Plan artifacts: .plan/<feature-slug>/

Type 'discard' to confirm.
```

## Red Flags

- **Never** proceed with failing tests
- **Never** merge without re-running tests on the merge result
- **Never** skip the acceptance criteria check
- **Never** discard without typed confirmation
- **Never** report "feature complete" without fresh verification output

## Guidelines

- Read each file at most once.
- The acceptance criteria check is the most important step. If it's incomplete, the feature is incomplete — even if all tests pass.
- ADRs created during the pipeline (`.claude/skills/adr-*/`) should NOT be cleaned up. They persist as guidance for future features.
- If the pipeline was interrupted (partial completion), report what's done and what's not. Don't pretend it's complete.
