---
description: Adversarial, non-security code review skill for Claude Code — upfront scope negotiation (full project vs. MR/diff only, related repos), eleven quality-dimension checklists (memory usage, comment verbosity, naming, architecture, dead code, missing tests, unnecessary tests, adversarial correctness, persistence, resilience, project conventions), cross-cutting passes on docs, test harness fidelity and query cost, optional runtime verification on a disposable database, isolated git worktrees, and an interactive HTML triage report where every finding can be validated, invalidated, delayed, and edited in place.
tags:
  - code-review
  - code-quality
  - refactoring
  - maintainability
  - architecture
  - database
  - dead-code
  - testing
  - html-report
  - sub-agents
---

# code-review-v2 — Adversarial Quality Assessment Engine

A code review skill for Claude Code, structured after [`security-audit-v2`](../../security/security-audit-v2/)
but aimed at everything a security audit deliberately ignores: maintainability, readability,
architecture, dead code, and test quality. The codebase (or just the diff) is assigned structured
**sprint task backlogs** built from pre-established checklists, reviewed adversarially, and every
finding lands in an **interactive HTML triage report** — not a static list.

---

## Scope: What Is Reviewed

The skill asks upfront whether to review the **Full Project** (partitioned into functional domains,
same scaling rules as `security-audit-v2`) or an **MR / Diff Only** (one agent per dimension working
the same diff in parallel, like a refute-first specialist review). It never offers a quick/sampling
mode — thoroughness is the only mode.

Eleven quality dimensions, each with its own checklist under `skills/code-review-v2/templates/checklists/`:

* **Memory Usage** — unbounded growth, missing resource cleanup, inefficient allocations, retained references, goroutine/object lifetime mismatches.
* **Comment Verbosity** — filler comments that restate the code (a common AI-generated-code smell), narration instead of clear naming, stale/commented-out code, and the opposite failure — missing WHY on genuinely non-obvious code.
* **Naming Logic** — ambiguous or misleading names, inconsistent terminology for the same concept, convention drift, generic package/interface names.
* **Architecture** — layering violations, leaky abstractions, god objects, shallow modules, premature abstraction, inconsistent error-handling strategy, pattern drift.
* **Dead Code** — unused symbols, unreachable branches, orphaned feature flags, duplicate implementations — every finding backed by a reference-search command and its empty result.
* **Missing Tests** — untested critical logic, error paths, boundaries, concurrency, regressions without a matching test.
* **Unnecessary Tests** — mock-only assertions, tautological tests, duplicate coverage, implementation-coupled tests, flaky-by-design tests, tests-for-the-framework.
* **Adversarial Correctness** — a general refute-first pass: nil/zero-value handling, boundary conditions, swallowed errors, unsynchronized shared state, assumed idempotency, contract mismatches, the order in which refusals are checked (a body validated before the resource is loaded turns a `403`/`404`/`412` into a `400`), and compensations that assume a failed commit rolled back.
* **Persistence** — query cost per call (pages that enumerate the whole set because the cursor and `LIMIT` sit outside a `UNION`), index fit, unused or overly broad indexes, updates rewriting large columns, ambiguous commits, rollbacks on cancelled contexts, pool and migration settings, unbounded tables.
* **Resilience** — deadlines on every hop, bounds on user input, per-request memory against the container limit, proxy and header assumptions (compression and `Content-Length`, cache directives), configuration defaults defined twice.
* **Project Conventions** — every rule the project wrote down (`CLAUDE.md` at every level, `AGENTS.md`, `CONTRIBUTING.md`, linter configs) extracted into `00-project-rules.md` and checked file by file, old code included; instruction files contradicted by the code are findings too.

Beyond the per-unit checklists, cross-cutting passes look at the composed system: **architecture**,
**claims vs. code** (every statement the docs make about call chains, security controls, limits and
status codes), **harness fidelity** (what the e2e setup and the real-instance tools replace compared
with production, and which observable behaviors no tool checks), and a **persistence** matrix of every
query, index and write statement. When allowed, a runtime step applies the migrations to a disposable
database, seeds realistic volumes and attaches `EXPLAIN` plans to the findings.

Every finding requires evidence proportional to its claim — a dead-code claim needs the exact
reference-search command and its zero-hit result; a missing-test claim needs confirmation the branch
is genuinely unreached; everything else needs an exact `file:line` and a reason a reviewer would agree
with on sight.

---

## Architecture & How It Works

```
Phase 0: Scope Negotiation (00-scope.md, 00-profile.md, 00-project-rules.md)
   │      Full Project vs. MR/Diff Only, related repos, disposable containers allowed?
   │
Phase 0.5: Domain/Diff Slicing & Backlog Generation (units/<unit>/tasks.md)
   │
Phase 1: Isolated Subagent Execution (wt-<unit>, evidence-backed findings)
   │     ├── Phase 1.5: Cross-Cutting Passes (architecture, claims, harness, persistence)
   │     └── Phase 1.6: Runtime Verification (optional: migrations + seeded data + EXPLAIN)
   │
Phase 2: Consolidation & Interactive Triage Report Generation (comments.json, report.html)
   │
Phase 3: Worktree Cleanup
```

**Full Project scope**: functional domains are the scaling axis (same thresholds as
`security-audit-v2`: split above 20 files / 5,000 LOC / 10 tasks). Each domain agent runs every
in-scope dimension's checklist against its own slice.

**MR / Diff Only scope**: the diff is the unit. One agent per dimension reviews the same diff in
parallel (deeper focus than splitting a small diff by domain). Large diffs (>20 changed files or
>2,000 changed LOC) are split by directory/package. Every finding records `introduced_by_mr`
(`yes`/`no`/`unknown`) so the user can tell what the MR actually caused versus what it merely touched.

### The Interactive Triage Report

`report.html` is not a static list — it's the deliverable the user works from:
* **Validate / Invalidate / Delay** any finding with one click; status is color-coded on the card.
* **Edit the comment to leave** and **the proposed action** in place, for every finding — both start
  pre-filled with specific text, never boilerplate.
* **Copy Prompt** builds a ready-to-paste LLM prompt for a finding from its fixed context plus the
  current (possibly edited) comment and proposed action — always reflects the latest edits, not the
  original generated text.
* **Questions**: add a question or ask for a suggestion on any finding, get a **Copy Prompt to Answer**,
  and paste the LLM's reply back in — it's added to a threaded discussion (you / Claude) attached to
  that finding, independent of its validate/invalidate/delay status.
* Triage state — status, edits, and question threads — autosaves to the browser's `localStorage`, so
  reopening the same report preserves progress.
* **Export Triage JSON** downloads the full current state (including edits and threads) for a
  permanent record.
* **Export Validated as Markdown** produces ready-to-paste comments for the ones you validated.
* Filters by severity, category, status, open/answered/no questions, plus free-text search.

---

## Output Layout

All deliverables are generated within `.code-review/<YYYY-MM-DD-HHMM>/`:

```
.code-review/<run>/
├── 00-scope.md                 # Agreed scope: full project or MR/diff, dimensions included
├── 00-profile.md               # Project tech stack, reviewed Git ref, verification tools inventory
├── 00-project-rules.md         # Numbered rules and claims extracted from CLAUDE.md, CONTRIBUTING, linters
├── units/
│   ├── <domain-or-diff-slice>/
│   │   ├── unit-profile.md     # Boundaries & files in scope
│   │   ├── tasks.md            # Sprint checklist backlog (all in-scope dimensions)
│   │   ├── findings.json       # Structured findings (schema-validated)
│   │   └── notes.md            # Coverage notes
├── findings/
│   ├── architecture.json        # Cross-cutting passes (Phase 1.5)
│   ├── claims.json
│   ├── harness.json
│   └── persistence.json
├── comments.json                # Consolidated findings, status: "pending", ready for triage
├── report.html                  # Interactive triage report
├── full-report.md               # Complete Markdown report
└── summary.md                   # 1-page executive brief
```

---

## Finding Schema

Each finding in `findings.json` / `comments.json` conforms to `templates/finding-schema.json`:
* `category`: one of the eleven dimensions above.
* `severity`: `Critical` / `Major` / `Minor` / `Nitpick`.
* `confidence`: `verified` (backed by a reference search, trace, quoted assertion or `EXPLAIN` plan),
  `opinion` (a judgment call for the user to weigh), or `needs-confirmation` (depends on a system
  outside the repo).
* `settle_with`: the exact command or test that proves or refutes the finding in one run; required for
  `needs-confirmation`, and listed under **Settle first** in `summary.md`. Multi-hop findings get
  dismissed as false alarms when the reader checks only one hop; this makes them cheap to settle.
* `suggested_comment` / `proposed_action`: the editable text surfaced in the report.
* `status`: `pending` / `validated` / `invalidated` / `delayed`, set by the user in `report.html`.
* `questions`: threaded discussion (`role: "user"` / `role: "assistant"`), always `[]` when generated —
  populated by the user in `report.html`, never by a review subagent.

---

## Safety Rails

This skill is **read-only and advisory**. It never modifies tracked files and never applies a fix —
proposed actions are text for the user to accept, edit, or reject, not code changes. All work happens
in isolated git worktrees under `.code-review/<run>/`, removed on completion. Sibling repos are read,
never edited, and the optional runtime step only uses disposable containers it starts and removes
itself.

---

## Installation

### As a Claude Code skill (per-project)
```
your-repo/
└── .claude/
    └── skills/
        └── code-review-v2/
            ├── SKILL.md
            └── templates/
```

### As a global skill (all projects)
Place it at `~/.claude/skills/code-review-v2/`.

---

## Usage

```
Run a code review of this codebase using the code-review-v2 skill.
```

The orchestrator will ask whether to review the full project or just an MR/diff before dispatching
subagents.
