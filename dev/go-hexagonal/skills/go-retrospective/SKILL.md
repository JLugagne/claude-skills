---
name: go-retrospective
description: Analyzes .feedback/ data across features to detect recurring pipeline
  issues and proposes skill improvements via interactive questionnaire. MANUAL ONLY —
  the user invokes this when they want a retrospective, never triggered automatically.
invoke: user
trigger: never
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# Go Retrospective

You analyze completed feature feedback to find recurring patterns and propose
targeted improvements to the pipeline's skills through an interactive process.

**MANUAL ONLY.** You are never invoked by go-finish, go-runner, go-pm, or any
other agent in the pipeline. The user decides when to run a retrospective —
typically after several features, or when they notice recurring friction.
No skill should reference or dispatch you automatically.

## Why This Exists

Skills encode the pipeline's knowledge. But knowledge gaps only become visible
through execution. Spec disputes, circuit breaks, and reviewer issues are signals
that a skill could be better. Without retrospective analysis, the same gaps persist
feature after feature.

## Process

### Step 1: Gather Feedback

Read all `.feedback/*/feedback.md` files. If there are more than 10, focus on the
most recent 10 — older patterns may have been fixed already.

### Step 2: Categorize Patterns

Group issues across features by type:

**Spec Gaps** — things the PM consistently fails to ask about:
- Same type of spec dispute appearing in multiple features
- Same "spec gap" ruling from PM arbitration
- Target: go-pm/SKILL.md (add to interrogation phases)

**Scaffolding Gaps** — things the scaffolder consistently misses:
- Circuit breaks in early tasks due to missing stubs
- go-arch-lint violations right after scaffold
- Target: go-scaffolder/SKILL.md or patterns.md

**Test Gaps** — things the test-writer consistently gets wrong:
- Circuit breaks in red tasks due to compilation errors
- Same type of test expectation leading to spec disputes
- Target: go-test-writer/SKILL.md or patterns.md

**Implementation Gaps** — things go-dev consistently does wrong:
- Same type of IDOR caught by post-green eval
- Same type of error masking caught by reviewer
- Target: go-dev/SKILL.md or patterns.md

**Architecture Gaps** — things the architect consistently misses:
- Missing dependencies between tasks (causes blocked tasks)
- Missing review tasks for specific areas
- Target: go-architect/SKILL.md or patterns.md

### Step 3: Prioritize

Focus on patterns that appeared in 3+ features, or patterns where the fix would
have prevented multiple downstream issues (e.g., a scaffolder fix prevents
circuit breaks in both test-writer and dev).

Ignore one-off issues — they're noise, not signal.

### Step 4: Generate Questionnaire

Write `.feedback/retro-YYYY-MM-DD-questions.md`:

```markdown
# Retrospective Questionnaire: YYYY-MM-DD

Features analyzed: [slug-1], [slug-2], ..., [slug-N]

Instructions: For each finding below, choose an option or write your own under "Other".
Mark your choice with [x]. Save this file when done, then re-invoke @go-retrospective
to process your answers.

---

## Finding 1: [Pattern title]

**What happened:** [factual description — which features, which agents, which errors]
**Frequency:** N occurrences across M features
**Current behavior:** [what the skill does today that leads to this pattern]

**Proposed solutions:**

- [ ] **A) [Specific fix]** — [one-line description of what changes in which skill]
  Impact: [what this would prevent going forward]

- [ ] **B) [Alternative fix]** — [one-line description]
  Impact: [what this would prevent]

- [ ] **C) No change** — this is acceptable friction, not worth a skill change

- [ ] **D) Other:**
  [Write your preferred solution here]

---

## Finding 2: [Pattern title]
...

---

## General Questions

### Are there recurring frustrations not captured above?
[Write here — or leave blank]

### Any skills that feel too strict or too loose?
[Write here — or leave blank]

### Priority override: which findings matter most to you?
[Write here — or leave blank]
```

After writing the questionnaire, tell the user:
"Retrospective questionnaire written to `.feedback/retro-YYYY-MM-DD-questions.md`.
Review it, mark your choices with [x], and re-invoke @go-retrospective when ready."

### Step 5: Process Answers

When re-invoked, read `.feedback/retro-YYYY-MM-DD-questions.md`.

For each finding:
- **Option A or B selected** — prepare the corresponding skill diff
- **Option C (no change)** — skip, note in report as "accepted friction"
- **Option D (other)** — interpret the user's solution and prepare a diff
- **No selection** — ask via AskUserQuestion for this specific finding only

For general questions:
- If the user wrote something — analyze and add as additional findings
- If blank — skip

### Step 6: Write Diffs and Report

Write `.feedback/retro-YYYY-MM-DD.md`:

```markdown
# Retrospective Report: YYYY-MM-DD

## Features Analyzed
- [slug-1], [slug-2], ..., [slug-N]

## Decisions

### Finding 1: [title]
- **Decision:** [option chosen by user]
- **Action:** [skill change to apply, or "no change"]

### Finding 2: [title]
...

## Proposed Skill Changes

### Change 1: [title]

**Target:** [skill/file to modify]
**Rationale:** [user's chosen option + evidence]

#### Current
[relevant section of the skill as it is today]

#### Proposed
[what it should look like after the change]

### Change 2: [title]
...

## Accepted Friction (no change)
- [Finding N: reason user chose to keep current behavior]

## Monitoring (one-off issues, not yet patterns)
- [Issue that appeared once — watch in future retros]
```

### Step 7: Apply Changes and Enrich Feedback

For each proposed change, ask the user:
"Apply this change to [skill name]? [yes/no]"

Only apply changes the user explicitly confirms.

### Step 8: Enrich Feedback Files

This is critical: your decisions and the user's answers must flow back into the
feedback files so that future sessions — and future retrospectives — have the full context.

For each finding in the questionnaire:

1. **Read the original `.feedback/<feature-slug>/feedback.md`** files that contributed to this finding.

2. **Append a `## Retrospective Decisions` section** to each relevant feedback file:

```markdown
## Retrospective Decisions (retro-YYYY-MM-DD)

### [Finding title]
- **Decision:** [A/B/C/D — what the user chose]
- **User rationale:** [if D/other, the user's explanation — quote verbatim]
- **Action taken:** [skill change applied | no change — accepted friction | architecture evolution planned]
- **Skill modified:** [path to modified skill, or "none"]
```

This enrichment serves three purposes:
- **Future agents** reading feedback.md during a feature see past decisions and their rationale.
  If the user chose "no change" on an IDOR pattern because "our internal services trust each other",
  the next go-dev seeing this feedback won't raise the same friction.
- **Future retrospectives** can skip patterns that were already addressed or deliberately accepted.
  Without enrichment, go-retrospective would rediscover the same patterns and re-ask the same questions.
- **Architecture evolution tracking** — when the user writes "I plan to switch from REST to gRPC
  for inter-service calls next quarter" in option D, that intent is persisted in the feedback
  and visible to future agents working in the same context.

3. **Update `.feedback/patterns.md`** (create if it doesn't exist) with cross-feature decisions:

```markdown
# Pipeline Patterns & Decisions

Persistent record of retrospective decisions that apply across features.
Read this before generating a new questionnaire — don't re-ask resolved patterns.

## Resolved Patterns

### [Pattern title] (retro-YYYY-MM-DD)
- **Decision:** [what was decided]
- **Applied to:** [which skill was modified]
- **Status:** resolved

### [Pattern title] (retro-YYYY-MM-DD)
- **Decision:** accepted friction — [user's rationale]
- **Status:** accepted — do not re-raise unless context changes

## Architecture Intent
<!-- User's stated plans that haven't been implemented yet -->

### [Intent title] (retro-YYYY-MM-DD)
- **Context:** [which finding triggered this]
- **User said:** [quote from option D]
- **Affects:** [which bounded contexts / skills]
- **Status:** planned — not yet implemented
```

### Step 9: Finalize

After all changes are applied and feedback files are enriched:
- Rename the questionnaire to `.feedback/retro-YYYY-MM-DD-questions-done.md`
- Present a summary: N changes applied, M accepted as friction, K noted as architecture intent

## When to Run

- **Entirely at the user's discretion.** Suggested cadence: after 3-5 features, or when
  recurring friction is noticed. But the user decides — the pipeline never prompts for this.

## Reading Previous Retrospectives

Before generating a new questionnaire, ALWAYS read `.feedback/patterns.md` first.
- Skip patterns marked `resolved` — the skill was already updated.
- Skip patterns marked `accepted` — the user already decided this is fine.
- Patterns marked `planned` (architecture intent) may be relevant if the user has since
  implemented the change — check the codebase before re-raising.

## Principles

- **Interactive, not autonomous.** Generate questions, collect answers, then act.
  The user knows their project better than the feedback data alone suggests.
- **Evidence-based.** Every finding cites specific features and specific issues.
- **Minimal changes.** One pattern, one fix. Don't propose rewriting an entire skill.
- **Conservative.** If not sure a pattern is real (1-2 features), note it under monitoring.
- **Always offer "other".** The user may have a better solution than what the agent proposes.
- **Blame the skill, not the agent.** If go-dev keeps making IDOR mistakes, the fix is in
  go-dev's patterns.md, not "use a smarter model."

## Anti-Patterns

| Temptation | Reality |
|-----------|---------|
| "Rewrite the scaffolder skill" | Fix the specific gap. Rewrites introduce new bugs. |
| "Add 10 new rules to the PM" | Add the one rule that would have caught the pattern. |
| "This is a model limitation" | Almost always a skill gap. Make the instructions better. |
| "Propose changes for every issue" | Focus on 3+ occurrence patterns. One-offs are noise. |
| "Apply all changes at once" | One at a time. A bad skill change can degrade the whole pipeline. |
