---
description: "Use when a feature pipeline is fully complete — all tasks green, all reviews passed, acceptance criteria met. Guides final verification, cleanup of .plan/ artifacts, and branch integration (merge, PR, or keep)."
---

# Go Finish

Guide completion of a feature after the full pipeline has run. Verify everything, clean up, and integrate.

## The Process

### Step 1: Final Verification

**Before presenting options, run the full verification suite:**

Read the [Verification Commands](patterns.md#verification-commands) pattern in patterns.md when running this.

**If anything fails:** Stop. Do not proceed. Report the failure and suggest whether go-fixer or go-debugger is appropriate.

**If skipped tests remain:** These are unimplemented test stubs from scaffolding. Either they were intentionally deferred (user decision) or they were missed. Ask the user.

### Step 2: Acceptance Criteria Check

Read `.plan/<feature-slug>/FEATURE.md` and check every item in "Definition of Done":

Read the [Acceptance Criteria Check](patterns.md#acceptance-criteria-check) pattern in patterns.md when writing this.

For each item: either point to evidence (test name, command output) or flag it as unverified.

### Step 2b: Update Project Map

Read `docs/project/SKILL.md`. Update:
1. The context table if a new context was created
2. The entity/endpoint/event counts for modified contexts
3. The "Latest Migration" number
4. The "Recent Features" list (add this feature, keep last 5)

Then read `docs/project/contexts/<context>.md` for each context touched by this feature.
Update:
- New entities, fields, or invariants
- New or modified service interfaces
- New or modified endpoints
- New or modified events
- New migration files

If the context doc doesn't exist, create it following the template above.

Keep updates factual — list what exists, don't interpret. The doc is a map, not a narrative.

### Step 3: Review Summary Report

Read all `.plan/<feature-slug>/task-*_SUMMARY.md` files and `.plan/<feature-slug>/task-rev-*` (reviewer task files) to produce a concise report:

Read the [Review Summary Report](patterns.md#review-summary-report) pattern in patterns.md when writing this.

### Step 3b: Compile Feedback

Read all `.plan/<feature-slug>/task-*_SUMMARY.md` files. For each task, extract:
- SPEC_DISPUTE summaries and their resolutions
- CIRCUIT_BREAK summaries and their resolutions
- Guardrail findings (from pre-green and post-green eval notes in summaries)
- Reviewer-created fix tasks (task-rev-* files) and their categories

Write `.feedback/<feature-slug>/feedback.md` following the [Feedback Template](patterns.md#feedback-template).

This is factual compilation, not interpretation. List what happened, not what should change.
The retrospective agent handles interpretation.

### Step 4: Plan Artifacts Cleanup

Ask: "Should I archive the .plan/<feature-slug>/ directory?"

- **Archive** (recommended): move to `.plan/done/<feature-slug>/` — preserves history
- **Delete**: remove `.plan/<feature-slug>/` entirely
- **Keep**: leave as-is (useful if more work is expected)

### Step 5: Present Integration Options

Read the [Integration Options](patterns.md#integration-options) pattern in patterns.md when presenting this.

### Step 6: Execute Choice

#### Option 1: Merge Locally
Read the [Merge Locally](patterns.md#merge-locally) pattern in patterns.md when executing this.

#### Option 2: Push and Create PR
Read the [Push and Create PR](patterns.md#push-and-create-pr) pattern in patterns.md when executing this.

#### Option 3: Keep As-Is
Report: "Branch preserved. Plan artifacts at `.plan/<feature-slug>/`."

#### Option 4: Discard
**Require typed confirmation.**
Read the [Discard Confirmation](patterns.md#discard-confirmation) pattern in patterns.md when presenting this.

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
