# Runner Prompt Templates

Templates for go-runner to use when dispatching subagents. Read the specific section you need.

## Pre-Green Guardrail Prompt

Use this when dispatching a Haiku guardrail check before a green task.

```
Launch Agent and prompt:
Quick consistency check for a green-phase task.

# Task
<content of .plan/<feature-slug>/task-<id>.md>

# Feature Spec
<relevant section from .plan/<feature-slug>/FEATURE.md>

# Red Task Summary (what tests expect)
<content of the paired red task's summary>

Check for obvious mismatches:
1. Do the test expectations in the red summary align with FEATURE.md?
   — Look for behaviors the test asserts that aren't in the spec
   — Look for spec requirements the test doesn't cover (less critical, but worth flagging)
2. Does the task file reference files that exist?
   — If "Relevant Code Files" lists a path, it should be a real file
3. Are there conflicting requirements between the task and spec?
   — e.g., task says "return 404" but spec says "return empty list"

Return ONLY: "PASS" or "MISMATCH: <one-line explanation>"
Do NOT attempt to fix mismatches — just report them.
```

## Subagent Dispatch Prompt

Use this when dispatching any task subagent (scaffolder, test-writer, dev, etc.).

```
You are working on a Go project following hexagonal architecture with red-green TDD.

# Your Task
<content of .plan/<feature-slug>/task-<id>.md>

# Context from Previous Tasks
<content of each dependency's task-<dep>_SUMMARY.md>
— Include ALL dependency summaries, not just the immediate parent.
— These carry the file manifest: which files were created/modified by earlier tasks.
— The subagent needs this to know which files to read beyond "Relevant Code Files".

# Skill & Model
Use subagent_type: <skill-name>
Use model: <model from the task's "## Model" field, or from the Model column in TASKS.md>
— The framework loads the skill automatically. Do NOT inline SKILL.md content.
— The model parameter overrides the skill's frontmatter model. If the task has no Model field, default to sonnet.

# Output
Return ONLY a short summary:
- Files created/modified (one per line with created/modified status)
- What was done (1-3 sentences)
- Any issues or blockers
If you hit a circuit breaker, start with CIRCUIT_BREAK:
If you disagree with a test expectation, start with SPEC_DISPUTE:
```

## Post-Green Eval Prompt

Use this when dispatching a Haiku eval after a green task passes verification.

```
Launch Agent and prompt:
Quick eval of a completed green-phase task.

# Task Summary
<content of task summary including files modified>

# Security Constraints (from task file)
<security constraints section from the task file>

Read ONLY the files listed in "Files Modified". Check for:
1. IDOR: Every query on scoped entities includes scope ID?
   — Look for SQL/queries that filter by entity ID alone without scope
   — Check repository method signatures include scopeID parameter
2. Layer violations: Run `go-arch-lint check` — report any violations.
   — This is DETERMINISTIC. If go-arch-lint says it's clean, it's clean.
   — Only flag layer issues if go-arch-lint reports them.
   — Skip the manual import check — the linter does it better.
3. Error masking: All DB errors collapsed into not-found?
   — Only the driver's specific "no rows" error should map to domain not-found
   — Timeouts, connection errors must propagate as-is (500, not 404)
4. Missing scope filter: Query by entity ID alone without scope?
   — Every WHERE clause on a scoped entity must include AND scope_id = $N

Return ONLY: "CLEAN" or "ISSUE: <one-line description per issue>"
Do NOT attempt to fix issues — just report them.
```

## Spec Dispute Escalation Prompt

Use this when escalating a SPEC_DISPUTE to go-pm.

```
A spec dispute has been raised during implementation of feature <feature-slug>.

# Dispute
<content of the SPEC_DISPUTE summary from go-dev>
— Include the full dispute text: which tests, what's expected, what dev believes is correct

# Context
<content of .plan/<feature-slug>/FEATURE.md>
— The full spec — go-pm needs it to check whether the disputed behavior is specified

<content of the disputed task file>
— The task that triggered the dispute

Review the dispute. Decide whether the test expectation or the developer's concern is correct.
Update .plan/<feature-slug>/FEATURE.md if the spec needs correction.
Then invoke go-architect to create corrective tasks (new red-green pairs, modified tasks, or task deletions).
```
