# Go Finish Patterns

## verification-commands

Run these commands in order. Each checks a different failure mode: compilation errors, test failures, race conditions, and forgotten test stubs.

```bash
# Build — catches compilation errors before wasting time on tests
go build ./...

# Full test suite with race detection — the authoritative pass/fail signal
# -count=1 disables test caching so you always get fresh results
go test ./... -count=1 -race

# Check for any skipped tests (leftover TODOs from scaffolding)
# Skipped tests indicate unfinished work that may have been overlooked
# A non-zero count here means the feature may not be fully implemented
go test ./... -count=1 -v 2>&1 | grep -c "SKIP"
```

## acceptance-criteria-check

Check every item in the Definition of Done. Each line must point to concrete evidence (test name, command output) or be flagged as unverified.

```
## Acceptance Criteria Verification

- [x] All tests pass (go test ./... — evidence above)
  <!-- Link to the verification output from Step 1 -->
- [x] Project compiles (go build ./... — evidence above)
- [x] E2E tests cover happy path and error cases (TestXxx_E2E_*)
  <!-- Name specific test functions that cover each scenario -->
- [x] Security tests cover IDOR and validation (TestXxx_WrongProject_*)
  <!-- IDOR tests verify cross-tenant isolation -->
- [ ] Database migrations are idempotent (NEEDS VERIFICATION)
  <!-- Run migrations twice against a test DB to verify idempotency -->
...
```

## review-summary-report

Compile task summaries and reviewer findings into a single report. This is the artifact the user reads to understand what the pipeline produced.

```
## Feature Summary: <feature-slug>

### What was built
[2-3 sentences]
<!-- Summarize the business capability, not the implementation details -->

### Files created/modified
[List from task summaries — deduplicated]
<!-- Deduplicate because multiple tasks may touch the same file -->

### Review findings addressed
[From go-reviewer tasks — what was caught and fixed]
<!-- This shows the value the review step provided -->

### Open items (if any)
[Anything deferred or flagged during the pipeline]
<!-- These become inputs for the next feature cycle -->
```

## integration-options

Present these options verbatim. The numbered list gives the user a clear choice without ambiguity.

```
Feature complete and verified. What would you like to do?

1. Merge to main/master locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work
<!-- Option 4 requires typed confirmation — never auto-discard -->
```

## merge-locally

Merge the feature branch into main locally. Always re-run tests after the merge to catch integration conflicts that passed on the branch but fail on main.

```bash
git checkout main
git pull
# Merge the feature branch — use the branch name from the pipeline
git merge <feature-branch>
# Re-run tests on merged result — merge conflicts can break things
# that passed on the feature branch individually
go test ./... -count=1 -race
# Only delete the branch after tests pass on the merged result
git branch -d <feature-branch>
```

## push-and-create-pr

Push the branch and create a PR with the summary from Step 3. The PR body structure matches what reviewers expect: summary, test plan, and review notes.

```bash
git push -u origin <feature-branch>
# Create the PR with a structured body
# The title uses conventional commit format for changelog generation
gh pr create --title "feat: <feature-slug>" --body "$(cat <<'EOF'
## Summary
[From Step 3 report]
<!-- Copy the "What was built" section from the review summary -->

## Test Plan
- All unit, contract, and e2e tests pass with -race
- Acceptance criteria verified against FEATURE.md
- go-reviewer findings addressed
<!-- This tells human reviewers the automated checks are done -->

## Review Notes
[From go-reviewer report]
<!-- Include specific findings so reviewers know what was already caught -->
EOF
)"
```

## feedback-template

Compile pipeline signals from task summaries into a structured feedback file. This is factual compilation — list what happened, don't interpret.

```markdown
# Feedback: <feature-slug>

## Spec Disputes
<!-- Resolutions of SPEC_DISPUTE during this feature -->

### Dispute 1: [short title]
- **Trigger:** go-dev task-N disagreed with test expectation on [behavior]
- **Ruling:** [test correct | dev correct | spec gap]
- **Root cause:** [e.g., "PM didn't ask about pagination behavior"]
- **Spec change:** [what was added/modified in FEATURE.md, or "none"]
- **Corrective tasks created:** [task IDs, or "none — dev retried with clarification"]

## Circuit Breaks
<!-- CIRCUIT_BREAK events during this feature -->

### Break 1: [short title]
- **Agent:** [go-dev | go-test-writer | go-scaffolder]
- **Task:** task-N — [title]
- **Error:** [one-line error summary]
- **Resolution:** [go-fixer fixed | go-debugger found root cause | escalated to user]
- **Root cause:** [e.g., "missing import path in scaffolder output"]
- **Fix applied:** [what was changed]

## Guardrail Findings
<!-- Issues detected by the Haiku pre/post green evals -->

### Finding 1: [short title]
- **Phase:** [pre-green | post-green]
- **Task:** task-N
- **Issue:** [e.g., "IDOR: FindByID query missing tenant_id filter"]
- **Caught before implementation:** [yes/no]
- **Impact:** [e.g., "would have been caught by reviewer anyway" | "would have reached production"]

## Reviewer Issues
<!-- Issues found by go-reviewer that generated corrective tasks -->

### Issue 1: [short title]
- **Category:** [architecture | security | data | performance | compatibility]
- **Description:** [what was wrong]
- **Fix tasks created:** [task IDs]
- **Could this have been prevented earlier?** [e.g., "yes — if scaffolder enforced scope param order"]

## Metrics
- Total tasks: N
- Circuit breaks: N (N% of tasks)
- Spec disputes: N
- Guardrail catches: N pre-green, N post-green
- Reviewer issues: N
- go-arch-lint violations caught: N
```

## discard-confirmation

Require explicit typed confirmation before destroying work. List exactly what will be lost so the user makes an informed decision.

```
This will permanently delete:
- Branch: <name>
- Commits: <list>
  <!-- List commit hashes and messages so the user sees exactly what's lost -->
- Plan artifacts: .plan/<feature-slug>/
  <!-- Plan files contain the spec, tasks, and summaries -->

Type 'discard' to confirm.
<!-- Never accept "yes" or "y" — require the exact word to prevent accidents -->
```
