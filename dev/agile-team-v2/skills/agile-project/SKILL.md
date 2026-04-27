---
name: agile-project
description: "Use this skill whenever you are working on a Go project following the agile-team-v2 workflow — features in .features/, sprints in .sprints/, strategic ADRs in .adrs/, tactical/strategic decisions log in .decisions/, global architecture in .architecture/ (VISION.md + ARCHITECTURE.md + CONVENTIONS.md + INTEGRATIONS.md). The architect absorbs the ex-scaffolder role: scaffolds Go contracts (signatures with `panic(\"not implemented\")` bodies), inlines `// AC: <criterion>` + `// TODO(impl-<feat>, ac-<NNN>)` markers above each scaffolded body, and decides the `mechanical: true|false` flag in FEATURE.md frontmatter. The PM has two passes: passe 1 (FEATURE.md narrative — Why/Context/User journey/Out of scope/Open questions), passe 2 (inline `// SCENARIO:` + `t.Skip(\"not implemented\")` in business test skeletons within `pm_test_territories`, skipped if `mechanical: true`). The sprint-planner lists tasks **by code marker** in SPRINT.md (no separate TASK.md / TASK-red.md / TASK-green.md / SCAFFOLD.md / TASKS.md files — those v1 artifacts no longer exist). Spec isolation between red and green is preserved by **discipline**: red reads `// AC:` + `// SCENARIO:`, green reads `// AC:` + red's committed test assertions. There is one `red` agent and one `green` agent (no per-tier variants — anticipates bloc 3). Tactical DECISIONS authored by green during a sprint (under R2 strict rules: scope=tactical, revisit=true, necessary, referenced, Authored-By:green trailer) are surfaced in RETRO.md `decisions_to_statue:` and statued by the architect at the start of the next sprint via a Wave 1 task. The reviewer runs three passes (DoD via `scripts/check.sh`, Scenarios narrative-vs-tests, Security checklist). The `## Human override` section of REVIEW.md is human-only with strict 5-field format; security findings cannot be overridden without a Decision reference. Triggers: any Go file editing in this kind of project (must use go-surgeon — never generic Edit/Write/Read), sprint planning, feature breakdown, FEATURE.md / SPRINT.md / REVIEW.md / RETRO.md / DECISION-NNN-*.md mentions, dispute files in .disputes/, any of the product-manager/architect/sprint-planner/red/green/e2e-tester/reviewer/bug-detective agents, `Authored-By:` commit trailer, the `// AC:` / `// SCENARIO:` / `TODO(impl-...)` markers, or any repository containing .features/ / .sprints/ / .adrs/ / .architecture/ / .decisions/ directories. Consult before planning a sprint, before starting any task, before writing a commit, before creating a DECISION or ADR, before responding to a dispute, or whenever you need to know what artifact goes where."
---

# Agile Project Workflow — v2

Workflow for Go projects using strict TDD, sprint-based agile, **intent-in-code** (no prose intermediaries), and the new `.decisions/` log with two-zone frontmatter and `Authored-By:` trailer audit.

The intent of v2 is captured in one sentence: **the code and the tests are the authority of execution.** No `TASK.md`, no `TASK-red.md`, no `TASK-green.md`, no `SCAFFOLD.md`, no per-feature `ARCHITECTURE.md`, no `TASKS.md`. Acceptance criteria live as `// AC:` comments above scaffolded function bodies. User-journey scenarios live as `// SCENARIO:` comments above business test skeletons. The sprint-planner lists tasks by code marker, not by prose file. Spec isolation between red and green is preserved by **discipline**, not by separate files.

---

# Go file editing — ABSOLUTE RULE

**STRICTLY FORBIDDEN** to use `Edit`, `Write`, `Read`, `Grep`, or any generic tool to read or modify a `.go` file.

For **every** `.go` file without exception:

- Reading → `go-surgeon symbol` or `go-surgeon overview`.
- Creation → `go-surgeon create`.
- Modification → `go-surgeon patch_function`, `patch_struct`, `patch_interface`, `update`, `insert_call`, etc.

Applies even for a single-line change. No exceptions.

---

# Parallelization — ABSOLUTE RULE

Use sub-agents (`Agent` tool) or agent teams for any task composed of independent parts (no file conflicts, no result dependencies).

- Launch parallel work in a single message (multiple simultaneous tool calls, or a team spawn).
- Never execute sequentially what can be parallelized.
- Examples: scaffolding multiple features in parallel, writing independent tests, creating files in different packages.

## Parallelism granularity

Maximum theoretical fan-out (e.g., "23 independent red tasks") is rarely the right unit. Rate limits, token budgets, and the cost of recovering from concurrent crashes (see *Agent crash recovery*) make wide fan-outs fragile.

**Default heuristic — feature as the unit of parallelism:**

- One agent per feature, traversing all tasks of that feature (all reds first, then all greens, in dependency order).
- Features run in parallel with each other.
- Within a feature, tasks run sequentially under one agent — that agent keeps the feature context warm across tasks.

This caps live agents to roughly the number of features in scope (typically 2–4 per sprint). It trades some theoretical parallelism for crash containment: a rate-limit on one feature does not corrupt three others' in-flight state.

**When to deviate (sprint-planner's call):**

- A feature with one heavy `architectural` task and several `mechanical` tasks: split the feature across two agents — the heavy task does not block the easy ones.
- A scaffold-only wave: the architect's scaffolding step is short-lived; running it for several features in parallel is fine.
- An e2e wave at sprint end: e2e tests for different features touch different test files; one agent per e2e is fine.

**What to avoid:**

- Spawning N agents where N equals task count (the v1 anti-pattern: 23 reds in parallel, 3 crashed mid-run, batch-commit lost work across all 23).
- Mixing red and green of the same task on the same agent — spec-isolation discipline breaks.
- Two agents writing to the same package concurrently (file-level races on `go-surgeon` edits).

The sprint-planner documents the chosen fan-out in `SPRINT.md` under `## Parallelization plan`, with a one-sentence rationale.

---

# Tests — ABSOLUTE RULE

Every non-mechanical feature **must** include:

- **Unit tests** for any logic in domain and application layers (table-driven, mocks via interfaces).
- **Contract tests** for each repository adapter (via testcontainers).
- **E2E / integration tests** at least one end-to-end scenario per `// SCENARIO:` marker.

Tests are produced **after scaffolding and before implementation**, following the strict red/green pattern. A non-mechanical feature without tests is not done.

For `mechanical: true` features, the test bar drops to "existing tests still pass" — there is no `// SCENARIO:` to materialize.

---

# Complexity classification — ABSOLUTE RULE

Every feature carries a `## Complexity` field in its FEATURE.md, one of `mechanical`, `standard`, `architectural`. **Distinct from the `mechanical:` frontmatter flag** — see the dedicated discussion in the `task-complexity-routing` skill.

- Missing complexity field fails DoR.
- The sprint-planner decides pipeline routing based on this field.
- A task can be **upgraded** in complexity during execution (via dispute type G), **never downgraded** while in flight. Over-classification is corrected in the retro for future calibration, not by demoting the running task.

Detailed classification heuristics, escalation signals, and retro calibration live in the `task-complexity-routing` skill. Load that skill only when classifying, routing, or reviewing classification accuracy — not for routine implementation work.

---

# Scaffolding-first — ABSOLUTE RULE (architect-owned)

Before red and green start a feature, the **architect** produces the testable contract — all exported types, interfaces, and function/method signatures with empty bodies (`panic("not implemented: ...")` or zero-value returns). The architect inlines `// AC: <criterion>` + `// TODO(impl-<slug>, ac-<NNN>)` above each scaffolded body that maps to an acceptance criterion derived from the user journey.

There is **no separate scaffolder agent** in v2 — the architect does both. The v1 `SCAFFOLD.md` artifact does not exist; the scaffolding evidence is the diff itself.

- One scaffolding pass per feature (one architect commit) before any red or green task starts.
- The architect couples with `scaffor` (https://github.com/JLugagne/scaffor) when configured to generate mocks and test scaffolds from the interfaces declared.
- All red tasks of the feature are blocked until scaffolding is committed.
- **Red cannot modify scaffolded signatures** or `// AC:` comments. If a signature is untestable, red raises a dispute (decision A — architect revises).
- **Green cannot modify scaffolded signatures** or add new exported symbols. Green may add **private (unexported)** helpers; logged in `RETRO.md helpers_added:` for retroactive coverage in a sub-sprint.

## SCAFFOLD Definition of Done (for the architect)

A scaffolding pass is **done** only when **every** item below is verifiable. Red cannot start until all are met:

- [ ] Every exported type required by the feature exists in code.
- [ ] Every exported interface exists with all method signatures (no method bodies — interfaces only).
- [ ] Every exported constructor / factory / function exists with its full signature.
- [ ] Every function body is exactly one of: `panic("not implemented: <feature-slug>/<fn-name>")` or a typed zero-value return. **No partial implementation.** No conditional logic, no helper calls, no early returns.
- [ ] Every body that maps to an acceptance criterion has `// AC: <description>` + `// TODO(impl-<slug>, ac-<NNN>)` immediately above. Numbering local to the feature, zero-padded to three digits, starting at `001`.
- [ ] If the feature touches `pm_test_territories`, empty `func TestXxx(t *testing.T) {}` test skeletons are scaffolded for the PM passe 2 to fill.
- [ ] `go build ./...` passes on the whole module (paste the output).
- [ ] No production logic, no test assertions, no private helpers written.
- [ ] Mocks regenerated for every new interface (via `scaffor` or the project's mock generator).
- [ ] No exported symbol exists in the diff that isn't required by the feature.
- [ ] `mechanical:` flag set in FEATURE.md frontmatter (R1). Rationale mandatory if `true`.
- [ ] `## Relevant decisions` section added to FEATURE.md listing applicable DECISIONS and ADRs.
- [ ] Commit follows the `Feature:` / `Task:` / `Authored-By: architect` convention.

If any item cannot be satisfied, the architect opens a `.questions/` entry — never ships a partial scaffold.

---

# Red/Green pattern — ABSOLUTE RULE

All **production-code feature work** at `standard` or `architectural` complexity follows strict TDD with **paired teammates** and **discipline-based spec isolation**.

- **Red phase**: the `red` agent writes failing tests against the scaffolded contract. Cannot edit production code or scaffolded signatures.
- **Green phase**: the `green` agent implements scaffolded function bodies. Cannot edit test code, cannot modify scaffolded signatures, cannot add exported symbols.

## Spec isolation — by discipline, not by file

In v2 there are no `TASK.md`, `TASK-red.md`, or `TASK-green.md` files. Both red and green find their work via the inline marker `TODO(impl-<slug>, ac-<NNN>)` in the production code, looked up via `grep`. Their contracts are:

- **Red reads**: `// AC:` description on the scaffolded body, the scaffolded signature itself, applicable DECISIONS and ADRs, FEATURE.md `# User journey` for context, and (for business tests) the `// SCENARIO:` marker the PM placed in the matching test skeleton.
- **Green reads**: `// AC:` description, the scaffolded signature, **red's committed test assertions** (the only handoff between them), applicable DECISIONS and ADRs, existing production code in the same package for patterns.

Neither reads any "private spec" — none exists. Neither reads the other's in-flight work; the only handoff is the committed test files (red → green) and the committed implementation (green → reviewer / e2e-tester).

**Mono-assistant safeguard.** If the same Claude instance must be both red and green for the same task (no agent teams, working solo), the assistant completes red end-to-end, **commits** under `Task: <slug>-T<NNN>-red`, then **starts a fresh session** before reading anything green-side. The reset is what purges red's working memory. `check.sh` audits at sprint review: for every task where red and green were the same assistant, `git log` must show at least one commit between the red and green work.

## In scope vs out of scope of red/green

The rule applies to **production-code feature work**. It does **not** apply to mechanical maintenance, where there is a unique correct answer and no design decision.

| In scope of red/green (rule applies)                                  | Out of scope (rule does not apply)                              |
|-----------------------------------------------------------------------|-----------------------------------------------------------------|
| `complexity: standard` features                                       | Rename a local symbol with no API change                        |
| `complexity: architectural` features                                  | `gofmt`, `goimports`, linter auto-fixes                         |
| Bug fixes that change observable behaviour                            | Dependency bump with no API impact                              |
| New exported APIs, signatures, types                                  | Comment / log message / error string fixes                      |
| Behaviour changes covered by `// AC:` markers                         | Regenerating mocks after an interface change already decided    |
|                                                                       | `complexity: mechanical` features (mono-agent task)             |

When in doubt, classify **upward** (`standard` over `mechanical`). Under-classification is corrected by an in-flight upgrade dispute (type G); over-classification only wastes one cheap pair.

## Tier fusion (anticipates bloc 3 of the refonte doc)

There is **one** `red` agent and **one** `green` agent (sonnet by default). The v1 system of `red-haiku` / `red-sonnet` / `red-opus` and `green-haiku` / `green-sonnet` / `green-opus` is collapsed. For unusually complex tests or implementations, the sprint-planner spawns the same agent with a model override at spawn time:

```
Agent({ subagent_type: "red", model: "opus", description: "...", prompt: "..." })
```

The agent's behaviour is unchanged — only the underlying model differs. This anticipates bloc 3 of the refonte doc; the user opted into it for v2.

---

# Commit cadence — ABSOLUTE RULE

Each agent **commits after every completed task**, never in batches.

- One commit per `<TASK_ID>` (one per `<slug>-T<NNN>-red`, one per `<slug>-T<NNN>-green`, one per `<slug>-scaffold`, one per `<slug>-pm2`, etc.).
- A teammate finishing two tasks in a row produces two commits, not one squashed commit.
- Do not defer commits to the end of a wave or end of sprint.

This bounds the blast radius of an agent crash, rate-limit interruption, or session loss to **one task** instead of a whole wave.

---

# Agent crash recovery — ABSOLUTE RULE

When one or more teammates crash mid-wave (rate limit, session disconnect, OOM), follow this procedure before re-spawning. **Never** delete dirty state blindly.

## 1. Inventory dirty state

- `git status` — list every modified or untracked file.
- For each dirty file, classify:
  - **complete** — the task it belongs to is finished per its DoD; safe to commit.
  - **partial** — task started, not finished; salvage decision needed.
  - **stale** — leftover from a task that was already committed elsewhere; safe to revert.
- Map dirty files → expected task scope using `SPRINT.md`. Files outside any in-flight task scope are suspect — investigate before touching.

## 2. Salvage vs revert, per file

- **Partial** file on a critical path of a downstream task → **salvage**: complete the minimum needed to satisfy the task DoD, then commit under the original `<TASK_ID>`.
- **Partial** file non-load-bearing or duplicating work re-spawn will redo → **revert** that specific file (`git checkout -- <path>`).
- **Stale** file → revert.
- **Complete** file → commit under its `<TASK_ID>` immediately, before re-spawning anything.

## 3. Re-spawn with narrowed scope

- Exclude every task already committed (check `git log --grep="Task:"` for the sprint).
- Exclude every task whose files were just salvaged-and-committed.
- Pass the narrowed task list explicitly in the spawn prompt — do not let the agent infer scope from `SPRINT.md` alone.

## 4. Document the crash

Append a short entry to the sprint RETRO under `## Agent crashes (narrative)`: which agents, which wave, which tasks salvaged vs reverted, any lost work. This feeds the parallelization heuristic at retro time.

---

# Commits — ABSOLUTE RULE

Every commit message **must** reference feature and task:

```
<short description>

Feature: <feature-slug>
Task: <TASK_ID>
[Authored-By: <agent-id>]   <-- mandatory on .decisions/ and mechanical: changes
```

- `Feature:` slug under `.features/<slug>/`. `maintenance` for non-feature work.
- `Task:` includes phase suffix:
  - `<slug>-scaffold` (architect's scaffolding pass).
  - `<slug>-pm2` (PM passe 2).
  - `<slug>-T<NNN>-red` (red phase on AC marker NNN).
  - `<slug>-T<NNN>-green` (green phase on AC marker NNN).
  - `<slug>-E<NNN>` (e2e-tester on SCENARIO marker NNN).
  - `<slug>-REVIEW` (reviewer feature-level).
  - `SPRINT_00X-REVIEW` (reviewer sprint-level).
  - `SPRINT_00X-retro` (sprint-planner retro processing).
  - `<slug>-T<NNN>` (mono-agent task — no `-red` / `-green` suffix).
  - `<slug>-T<NNN>-bugfix` (corrective task after bug-detective report).
  - `<slug>-decision-review` (architect statuing a tactical DECISION).
  - `H<NNN>-red` (sub-sprint helper-coverage task).

Multiple tasks in one commit: `Task: T003-green, T004-green` (rare; cadence rule normally precludes).

**`Authored-By:` trailer** — mandatory whenever the commit:

- Creates, modifies, or deletes any file under `.decisions/`.
- Modifies the `mechanical:` field in any FEATURE.md frontmatter.
- Modifies the `review.reviewed_by` field in any DECISION.

Values: `architect` (architect's writes), `green` (green's tactical DECISIONS only). `check.sh` cross-checks `git blame` against the trailer (R6); mismatch is a CI block.

Branches: `<feature-slug>/<TASK_ID>-<short-description>` (e.g., `auth-login/T003-green-impl`).

---

# Push timing — ABSOLUTE RULE

A red wave produces tests that fail by design. A pre-push hook running `go test ./...` will reject these commits, and bypassing it (`--no-verify`) defeats the gate for everyone.

The rule:

- **Never push to `main`** (or any shared branch with a green-tests pre-push hook) **in the middle of a red wave.**
- A push to a shared branch is allowed **only** at the end of a complete green wave, when `go test ./...` passes locally.
- Within a wave, commits stay local (or on a per-feature branch) until the matching green completes.

Allowed branching strategies, pick one per project (document in `.architecture/CONVENTIONS.md`):

1. **Trunk + delayed push** (default for solo / small teams) — commit red and green locally on `main`, push only when the green wave finishes.
2. **Per-feature branch + sprint-end PR** — each feature lives on `<feature-slug>` branch; red and green commits push freely there (no green-tests gate on feature branches); sprint review opens a PR to `main` once all greens are complete.

What is **not** allowed:

- `git push --no-verify` to bypass the green-tests hook during a red wave.
- A custom hook escape hatch keyed off the commit message.

`check.sh` in CI mode audits `git log` over the sprint window for `--no-verify` markers (R4).

---

# Roles summary (8 agents)

| Role             | Owns                                                                                              | Model  |
|------------------|---------------------------------------------------------------------------------------------------|--------|
| product-manager  | FEATURE.md (Why/Context/User journey/Out of scope/Open questions); `// SCENARIO:` markers in `pm_test_territories`; `.features/INDEX.md` (todo / ready transitions). | sonnet |
| architect        | `.architecture/`, `.adrs/` (strategic), `.decisions/` (strategic + reviewing tactical); scaffolded production signatures with `// AC:` + `panic`; `mechanical:` flag in FEATURE.md; `## Relevant decisions` section. | opus   |
| sprint-planner   | `.sprints/SPRINT_00X/SPRINT.md` (tasks listed by code marker); dispute decisions; `RETRO.md` `## Metrics` and YAML frontmatter (incl. `decisions_to_statue:`); sub-sprint creation; INDEX.md `ready` → `in-progress`. | opus   |
| red              | `*_test.go`, `testdata/`, `testutil/`, `mocks/` (replaces PM's `t.Skip` with assertions in business tests; writes fresh tests in non-business areas).            | sonnet |
| green            | Non-test `.go` files (function bodies in scaffolded stubs; private helpers); tactical DECISIONS in `.decisions/` under R2 strict rules; `RETRO.md helpers_added:` (append-only). | sonnet |
| e2e-tester       | E2E scenarios in `pm_test_territories` (transforms PM's `t.Skip` into real e2e against testcontainers).                                                            | sonnet |
| reviewer         | REVIEW.md `## Findings` (feature and sprint level); `.features/INDEX.md` `done`/`blocked` for feature it just signed off; `.sprints/INDEX.md` `done`. | sonnet |
| bug-detective    | `.bugs/<bug-id>.md` (post-mortem investigation; classification implementation-bug / spec-bug / architectural-bug; never proposes the fix).                          | sonnet |

---

# Project workflow

## Principles

- Work happens in sprints. Maintenance (typos, dep updates, linting, small refactors) can happen outside sprints.
- Every non-trivial decision is documented either as a strategic ADR (`.adrs/`) or as a DECISION (`.decisions/`).
- Blockers and open questions **always** require human input — no auto-resolution. No sprint, feature, or task starts while a blocker or open question is pending.
- Red and green operate with **discipline-based** spec isolation. Cross-reading in-flight work is forbidden; the only handoff is committed code/tests.
- DECISIONS and ADRs listed in FEATURE.md `## Relevant decisions` propagate naturally — every agent reads them via that section.

## Global architecture (.architecture/)

Owned by the **architect**. The directory replaces the v1 `OVERVIEW.md` with two distinct files:

- `VISION.md` — why the project exists. 50–100 lines. Audience: any new contributor or agent.
- `ARCHITECTURE.md` — data model, layer boundaries, runtime topology, technical choices. 200–400 lines.
- `CONVENTIONS.md` — coding conventions, error handling, logging, observability, branching, push timing, **`pm_test_territories`** glob block, marker formats (`// AC:`, `// SCENARIO:`, `TODO(impl-...)`).
- `INTEGRATIONS.md` — external services and contracts.
- Topic-specific files as needed: `AUTH.md`, `PERSISTENCE.md`, `OBSERVABILITY.md`, etc.

Every agent **reads** `.architecture/`. Only the architect writes.

The `pm_test_territories` declaration in `CONVENTIONS.md`:

```yaml
pm_test_territories:
  - tests/e2e-api/
  - tests/contract/
  - "**/usecase/*_test.go"
  - "**/usecases/*_test.go"
```

`check.sh` reads this block and rejects `// SCENARIO:` markers outside.

## Decisions (.decisions/) — NEW in v2

The decision log distinct from strategic ADRs. The architect writes strategic DECISIONS directly. Green may write **tactical** DECISIONS during implementation under R2 strict rules. The architect **statues** every tactical DECISION (`review.revisit: true`, `review.reviewed_by: null`) at the start of the next sprint via a Wave 1 task placed by the sprint-planner.

`.decisions/INDEX.md`:

```markdown
| ID            | Scope     | Status     | Title                            | Date       | Author    |
|---------------|-----------|------------|----------------------------------|------------|-----------|
| DECISION-042  | strategic | ACTIVE     | session storage backend          | 2026-04-15 | architect |
| DECISION-051  | tactical  | ACTIVE     | session-id format choice         | 2026-04-27 | green     |
```

`.decisions/DECISION-NNN-<slug>.md` — two-zone frontmatter:

```yaml
---
# Zone author — writeable at creation only
id: DECISION-051
date: 2026-04-27
scope: tactical          # tactical | strategic
status: ACTIVE           # ACTIVE | SUPERSEDED
author: green            # architect | green
affects: [internal/auth/session.go]

# Zone review — writeable by architect only, post-creation
review:
  revisit: true          # green sets true at creation; architect may flip false
  reviewed_by: null      # null at creation; "architect" after statuing
  reviewed_at: null
  outcome: null          # null | confirmed | reformulated | superseded
---

# <Title>

## Question
## Decision
## Rationale

## Reformulated by architect
(empty initially; filled at statue time if reformulating)
```

Every commit that creates or modifies anything under `.decisions/` carries the `Authored-By:` trailer (R6).

### R2 — Tactical DECISIONS by green

Green may write a tactical DECISION when **all four** hold:

1. `scope: tactical` (never `strategic` — reserved for the architect).
2. `review.revisit: true` at creation (never `false` initially).
3. The decision is **necessary to unblock the current task** — not opportunistic.
4. The DECISION-NNN is referenced in the code (a `// see DECISION-NNN` comment) or in the commit message body.

The sprint-planner surfaces each unstatued tactical DECISION in `RETRO.md` `decisions_to_statue:` at retro processing. The next sprint's plan starts with a Wave 1 task for the architect to statue every entry. CI rejects a sprint that closes with `review.revisit: true` and `review.reviewed_by: null` on a DECISION older than one sprint window (`check.sh` enforces).

The architect's three statuing outcomes:

- **Confirm** — `review.outcome: confirmed`, `review.reviewed_by: architect`, `review.revisit: false`. Body untouched.
- **Reformulate** — same review fields with `outcome: reformulated`. Rewrites `## Decision` and `## Rationale`. Fills `## Reformulated by architect`.
- **Supersede** — `status: SUPERSEDED`, `review.outcome: superseded`. Creates `DECISION-MMM-*.md` that supersedes this one. Updates `INDEX.md`.

The architect may also escalate a tactical DECISION to strategic if the scope turned out larger — promote `scope:` to `strategic` and possibly migrate to `.adrs/`.

## ADRs (.adrs/) — strategic only

Strategic, multi-feature, project-direction. Format unchanged from v1. `revisit: true` indicates an autonomous decision under uncertainty — picked up at retro for human review.

Tactical decisions go to `.decisions/`, not `.adrs/`. Do not mix.

## Features (.features/)

`INDEX.md` schema:

```markdown
| Slug                | Status      | Complexity     | Priority |
|---------------------|-------------|----------------|----------|
| auth-login          | ready       | architectural  | 1        |
| audit-log           | ready       | standard       | 2        |
| rename-user-field   | ready       | mechanical     | 3        |
```

`<slug>/FEATURE.md` — co-authored:

```markdown
---
title: <feature-slug>
status: ready
mechanical: false       # set by architect at end of scaffolding
# mechanical_rationale: <only if mechanical: true>
---

# Why                   <-- PM
# Context                <-- PM
# User journey           <-- PM
# Out of scope           <-- PM
# Open questions         <-- PM

## Complexity            <-- architect (with PM input)
<mechanical | standard | architectural>

## Complexity rationale  <-- architect

## Relevant decisions    <-- architect
- [.decisions/DECISION-051-...](...) — short reason
- [.adrs/007-...](...) — short reason
```

The architect adds **only** the `mechanical:` and `mechanical_rationale:` frontmatter fields and the `## Complexity`, `## Complexity rationale`, `## Relevant decisions` body sections. The PM owns everything else.

## Code markers — NEW in v2

The intent of every feature lives in two marker conventions, declared in `.architecture/CONVENTIONS.md`:

### `// AC:` — Acceptance Criterion (architect inlines, above scaffolded body)

```go
// AC: <one-line description of the criterion>
// TODO(impl-<feature-slug>, ac-<NNN>)
func (s *LoginService) Authenticate(ctx context.Context, c Credentials) (Session, error) {
    panic("not implemented: auth-login/Authenticate")
}
```

`<NNN>` zero-padded to three digits, local to the feature, starting at `001`. Stable for the feature's lifetime.

### `// SCENARIO:` — User-journey scenario (PM passe 2 inlines, in `pm_test_territories`)

```go
func TestLogin_ValidCredentials(t *testing.T) {
    // SCENARIO: Marie logs in with valid credentials and lands on her dashboard
    // TODO(impl-auth-login, scenario-001)
    t.Skip("not implemented")
}
```

`<NNN>` zero-padded, local to the feature, starting at `001`. Stable.

### Lifecycle of a marker

- **Architect scaffolds** — adds `// AC:` + `panic`. AC marker present, body panics.
- **PM passe 2** — adds `// SCENARIO:` + `t.Skip` in business test skeletons (skipped if `mechanical: true`).
- **Red** — locates `TODO(impl-<slug>, ac-<NNN>)`, writes failing assertions in the matching test file. For business tests, replaces only the `t.Skip` line — keeps `// SCENARIO:` and `// TODO(impl-...)` comments above.
- **Green** — replaces `panic("not implemented: ...")` with implementation. `// AC:` comment stays in place.
- **E2E-tester** — locates `TODO(impl-<slug>, scenario-<NNN>)`, replaces `t.Skip` with real e2e assertions. `// SCENARIO:` and `// TODO(impl-...)` stay.
- **Reviewer pass 2** — verifies every `// SCENARIO:` traces to a `# User journey` passage; every `# User journey` passage that warrants coverage has a `// SCENARIO:`.
- **Once a feature is `done`**: the `TODO(impl-<slug>, ...)` markers must be **removed** from code (the implementation is in; the TODO is no longer accurate). `check.sh` in CI mode rejects a feature `done` in INDEX.md with leftover `TODO(impl-<slug>, ...)`.

## Tasks — by code marker (no TASK*.md files)

Every red/green/e2e task corresponds to one `TODO(impl-<slug>, ac-<NNN>)` or `TODO(impl-<slug>, scenario-<NNN>)` marker in the code. The agent locates its work via:

```bash
grep -rn "TODO(impl-auth-login, ac-001)" .
```

The match points at the scaffolded body (for `ac-`) or the test skeleton (for `scenario-`). The agent's contract is the surrounding inline `// AC:` or `// SCENARIO:` description plus FEATURE.md `# User journey` and applicable DECISIONS / ADRs.

There are **no** `TASK.md`, `TASK-red.md`, `TASK-green.md`, `SCAFFOLD.md`, or per-feature `TASKS.md` files. Anyone tempted to create one should stop — the v2 convention is markers in code, not prose intermediaries. Spec isolation is preserved by discipline.

### Pipeline routing by complexity

The sprint-planner routes per the `task-complexity-routing` skill:

- `mechanical` → **mono-agent task**. Single line in SPRINT.md execution plan. No red/green pair. The architect (or a mono green) does both scaffolding and implementation. Reviewer at end. Pipeline shape minimal.
- `standard` → **reduced pipeline**. Architect scaffolds → PM passe 2 (if `mechanical: false`) → red → green → e2e-tester (if `mechanical: false`) → reviewer.
- `architectural` → **full pipeline**. Same as standard plus a mandatory strategic ADR before scaffolding starts.

`SPRINT.md` `## Routing decisions` section documents the choice per feature.

### Task types

- **Architect scaffold** (one per feature, first): inlines `// AC:`, scaffolds test skeletons, sets `mechanical:`.
- **PM passe 2** (one per non-mechanical feature): inlines `// SCENARIO:` in test skeletons.
- **Red task** (one per `// AC:` marker in scope): writes failing assertions.
- **Green task** (one per red task, paired): implements the body.
- **E2E task** (one per `// SCENARIO:` marker in scope, only on non-mechanical features): translates `t.Skip` into real e2e.
- **Feature REVIEW** (one per feature): reviewer's three passes, signs off `done` in INDEX.md.
- **Sprint REVIEW** (one per sprint): reviewer's cross-cutting checks.
- **Sprint retro** (one per sprint): sprint-planner generates `## Metrics` + YAML.
- **Architect DECISION-statuing** (when previous retro has `decisions_to_statue:` non-empty): Wave 1 task in the new sprint; architect confirms / reformulates / supersedes each pending tactical DECISION.

## Reviews (.features/<slug>/REVIEW.md and .sprints/SPRINT_00X/REVIEW.md)

Two sections:

- `## Findings` — the reviewer's three passes.
- `## Human override` — human-only, strict 5-field format. Empty by default.

### Three passes

**Pass 1 — DoD (technical).** Invokes `scripts/check.sh --mode ci`. Verifies golangci-lint, go test, go build, go vet, marker linting, `.decisions/` format, `## Human override` 5-field format, security-override Decision reference, `Authored-By:` trailer cross-check, `--no-verify` audit, INDEX.md ↔ reality coherence, unstatued tactical DECISIONS, `mechanical:` flag presence on scaffolded+ features.

**Pass 2 — Scenarios (business).** For each `// SCENARIO:` marker, locate the matching `# User journey` passage and verify alignment. For `mechanical: true` features, confirm zero `// SCENARIO:` markers exist. Identify user-journey passages without scenario coverage.

**Pass 3 — Security.** Walk the fixed checklist:

1. IDOR / object-level authz.
2. Authn / authz on every entry point.
3. SSRF.
4. Injection — SQL.
5. Injection — command / shell.
6. Injection — template.
7. Secrets in clear (logs, errors).
8. Input validation at the boundary.
9. Internal-error exposure.

Each item: `applied` / `non-applicable` / **`missing`** with `path:line` if missing.

### `## Human override` — strict format (R3)

```markdown
## Human override

### Override 001

- **Finding overridden:** internal/auth/handler.go:42 — input validation missing
- **Reason:** Validated upstream by the API gateway per DECISION-018; no need to duplicate in the handler.
- **Decision reference:** DECISION-018
- **Date:** 2026-04-29
- **Author:** lugagne.jeremy
```

The reviewer **never** writes in `## Human override`. `check.sh` enforces the 5 fields at pre-commit and CI; security-finding overrides without a `Decision reference` are blocked.

### Sprint-level cross-cutting checks

- All feature REVIEWs done.
- DECISIONS and ADRs consistent (no contradictions; superseding chains explicit).
- All blockers, questions, disputes resolved (with full `## Acknowledgements`).
- Helpers logged in `RETRO.md helpers_added:`.
- Tactical DECISIONS scheduled to statue: every `decisions_to_statue:` from previous sprint is now statued.
- RETRO.md YAML frontmatter complete.
- Push timing respected.
- Mono-assistant boundary respected.
- Scope SSOT (SPRINT.md is authoritative).
- `go test ./...` and `golangci-lint` green on `main`.

## Sprints (.sprints/)

- `INDEX.md` — sprints with start/end dates and status.
- `SPRINT_00X/SPRINT.md` — focus, features, execution plan as todo list **with code markers**.
- `SPRINT_00X/REVIEW.md` — sprint review checklist.
- `SPRINT_00X/RETRO.md` — retrospective.
- Sub-sprints `SPRINT_00X-Y` — micro-work that can't wait (helper coverage, tooling).

### Scope: single source of truth — ABSOLUTE RULE

Sprint scope (which features and tasks are in flight) lives in **one place only**: `.sprints/SPRINT_00X/SPRINT.md`. Every other artifact references it without duplicating.

| Artifact                                  | Role re: scope                                                            |
|-------------------------------------------|---------------------------------------------------------------------------|
| `.sprints/SPRINT_00X/SPRINT.md`           | **Source of truth.** Lists features in scope, wave graph, parallelization plan, agent assignments, code markers. |
| `.features/INDEX.md`                      | Backlog. `status: in-progress` is set for features currently in `SPRINT.md` scope, but `INDEX.md` does not list which sprint or which markers. |

Rules:

- The sprint-planner edits `SPRINT.md`. No other agent edits it.
- A change to scope mid-sprint (added unplanned task, descoped feature) is made in `SPRINT.md` first; `.features/INDEX.md` reflects derived status only.

### Retrospective (RETRO.md)

YAML frontmatter (sprint-planner) + prose `## Metrics` (sprint-planner) + prose `## Reflection` (human, never auto-filled).

```markdown
---
sprint: SPRINT_00X
metrics:
  planned_tasks: 14
  delivered_tasks: 13
  unplanned_tasks: 1
  disputes_raised: 2
  disputes_resolved: 2
  disputes_by_type: { A: 0, B: 1, C: 1, D: 0, E: 0, F: 0, G: 0 }
  agent_crashes: 0
  rework_commits: 2
helpers_added:
  - feature: auth-login
    package: internal/auth
    task: TODO(impl-auth-login, ac-002)
    symbol: hashPassword
    file: internal/auth/password.go
    rationale: bcrypt wrapping isolated for clarity
decisions_to_statue:
  - id: DECISION-051
    author: green
    affects: [internal/auth/session.go]
    raised_in_task: TODO(impl-auth-login, ac-001)
    rationale: session-id format choice needed during impl
crashes: []
adrs_to_revisit: []
complexity_routing:
  classification_accuracy: { correct: 12, total: 14 }
  upgrades: []
  observed_downgrades: []
  heuristic_adjustments: []
template_extensions: []
---

# Sprint 00X — Retrospective

## Metrics
[Sprint-planner — narrative summary derived from YAML.]

## Reflection
[Human-only. Empty until the human writes.]
```

### How the sprint-planner uses this

- **Sub-sprint planning**: `helpers_added:` drives auto-creation of `SPRINT_00X-A` (helper coverage). One `H<NNN>-red` task per helper.
- **DECISIONS to statue**: `decisions_to_statue:` drives the Wave 1 task block in the next sprint for the architect.
- **Cross-sprint health**: trends in `disputes_raised`, `agent_crashes`, `rework_commits` flag drift.
- **Calibration**: `complexity_routing:` feeds the `task-complexity-routing` skill's heuristics.

A retro without YAML frontmatter is **invalid**; the sprint review checklist rejects it.

## Sub-sprints (.sprints/SPRINT_00X-Y/)

For micro-work that can't wait, including **retroactive test coverage of private helpers**:

- Created by the sprint-planner after reading the main sprint's RETRO.
- Contains `H<NNN>-red` tasks (red-only, no green pair — helpers already exist).
- Tests must **pass** against existing helper implementations (exception to the normal "tests must fail" rule).
- DoD: each listed helper has tests, tests pass, coverage meets target.

Sub-sprint `SPRINT.md` cross-links back to the main sprint retro section that triggered it.

## Bugs (.bugs/)

`bug-detective` agent (sonnet, on-demand) investigates. Writes `.bugs/<bug-id>.md` with classification (implementation-bug / spec-bug / architectural-bug). Does **not** propose the fix.

The sprint-planner reads the report and routes:

- **implementation-bug** → corrective task `<slug>-T<NNN>-bugfix` (red reproduces as failing test, green fixes). Goes into the current sprint as unplanned if blocking, or next sprint backlog.
- **spec-bug** → `.questions/` for PM and/or architect. PM extends `# User journey`, architect revises `// AC:` and re-scaffolds. Then a new task pipeline.
- **architectural-bug** → architect amends or supersedes a DECISION / ADR. No corrective task until the decision layer is consistent.

Bug-detective is post-mortem; spec isolation rules don't apply to its reads (everything is committed).

## Blockers (.blockers/SPRINT_00X/)

- Multiple solutions as a checklist.
- **Always require human input.** Affected teammates stop.

## Questions (.questions/SPRINT_00X/)

```markdown
---
id: Q069
phase: planning              # prep | planning | execution
raised_by: architect
raised_on: 2026-04-22
references: [auth-login, TODO(impl-auth-login, ac-001)]
blocking_scope: planning     # feature-DoR | sprint-kickoff | task | sprint | none
---

# Question
## Suggested resolutions
- [ ] option A — ...
- [ ] option B — ...
## Answer
[free text, written by the human or — for technical-only questions — by the architect]
```

### Phase semantics

| `phase`    | When raised                                | Default `blocking_scope`           | Resolution deadline    |
|------------|--------------------------------------------|-----------------------------------|------------------------|
| `prep`     | While drafting FEATURE.md / DoR check      | `feature-DoR`                     | Before the feature reaches `ready` |
| `planning` | While the sprint-planner authors SPRINT.md | `sprint-kickoff`                  | Before sprint kickoff   |
| `execution`| Mid-sprint, while a task is in flight       | `task` (default) or `sprint`      | Before the dependent task closes (or sprint, if scope=sprint) |

Rules:

- A `prep` question blocks only the feature it references — other features can ship.
- A `planning` question blocks the **entire sprint kickoff** until resolved.
- An `execution` question with `blocking_scope: task` blocks only that task. Others proceed.
- An `execution` question with `blocking_scope: sprint` blocks all dependent work and triggers a planner pause.

## Disputes (.disputes/SPRINT_00X/)

One file per disputed task, named after the marker:

```
.disputes/SPRINT_00X/TODO_impl-auth-login_ac-001.md
```

Sections: raising party's dispute, paired teammate's response, sprint-planner's decision, acknowledgements.

The sprint-planner decides citing **only public artifacts** (the inlined `// AC:`, `// SCENARIO:`, FEATURE.md, ARCHITECTURE.md, DECISIONS, ADRs, scaffolded code, committed tests). There are no private specs to read in v2.

Decision types A–G preserved from v1:

- **A** — architect must revise (scaffold wrong, missing, or violates ARCHITECTURE.md / DECISIONS).
- **B** — red must revise (test unfulfilable, contradicts `// AC:`, over-specifies beyond contract).
- **C** — green must proceed under a stated interpretation.
- **D** — both must adjust (rare).
- **E** — escalate to architect via `.questions/` (gap in `.architecture/` or DECISIONS).
- **F** — escalate to human via `.questions/`.
- **G** — complexity upgrade. Default G-finish-then-escalate. G-immediate-rerun if current agent declares the task impossible at its assigned model. G-architect-loop if a missing DECISION is revealed.

**Mid-task agent handoff is forbidden.** Either the current agent finishes (G-finish-then-escalate) or work is reverted (G-immediate-rerun).

### Hat-switching declaration (mono-assistant safeguard)

If the same assistant wears multiple roles in one session (e.g., red earlier, now arbitrating as sprint-planner), append a hat-switch marker at the top of the dispute file before reading any artifact:

```markdown
## Planner hat activated: 2026-04-25 by <assistant-id>
Previous hats this session: red (TODO(impl-auth-login, ac-001))
Confirms: will read only public artifacts (code, tests, FEATURE.md, ARCHITECTURE.md, DECISIONS, ADRs).
```

A dispute file missing this marker, written by an assistant who acted as red or green earlier, is invalid at retro and must be re-litigated.

### Acknowledgement protocol

Sprint-planner notifies every teammate listed in `Action required:` via teammate message. Each appends a line to `## Acknowledgements`. Status flips to `resolved` only when every teammate has acked. Sprint REVIEW.md rejects a `resolved` dispute lacking acks.

## Tooling feedback (.tools/<tool-name>/)

Friction reports for tools (`go-surgeon`, `scaffor`, the workflow itself). Bug reports or improvement suggestions.

### Template evolution (scaffor and similar)

Scaffor templates and similar generator templates extend across sprints. Two routing modes depending on whether the extension is **blocking the current sprint**:

- **Blocking extension** — file under `.blockers/SPRINT_00X/template-<name>.md`. Affected scaffold tasks stop until the extension lands. Extension lives on the dependent feature's branch with `Feature: maintenance`, `Task: tooling-<short>`.
- **Non-blocking extension** — log under `template_extensions:` in the RETRO YAML with `blocking: false`. Sprint-planner aggregates non-blocking entries into `SPRINT_00X-tooling` after retro. No red/green pairing — architect-as-tooling + reviewer with `scaffor lint` + `scaffor test` gate.

Reject inline edits with no record — template drift across sprints causes silent regressions.

---

# Transverse rules R1 → R6 (mirror of `agile-team-refonte-bloc1.md`)

These rules cross-cut the workflow and are referenced throughout the agent specs.

## R1 — `mechanical:` flag (architect's exclusive authority)

The `mechanical: true|false` field in FEATURE.md frontmatter is set by the architect at end of scaffolding. The PM **never** touches it.

- `true` if every `// AC:` is wiring/plumbing pure (DI registration, DTO mapping 1-to-1, trivial adapter pass-through, schema migration, secret rotation, rename, dep bump, lint config, no-behaviour-change refactor).
- `false` as soon as any `// AC:` contains a business condition, an invariant, a calculation, an observable user interaction, or an effect on business state.

`mechanical_rationale:` mandatory if `true`, optional if `false`.

`check.sh`:

- Pre-`scaffolded` status: absence of `mechanical:` is OK.
- At status `scaffolded` or beyond: presence is mandatory; absence is a CI block.
- Modification of `mechanical:` by a commit whose `Authored-By:` trailer is not `architect`: CI block.

If `mechanical: true`: PM passe 2 is skipped, no `// SCENARIO:` markers expected, no e2e tasks planned. Reviewer pass 2 inverts (verifies zero `// SCENARIO:`).

## R2 — Green's tactical DECISIONS

Green may write a tactical DECISION under all four conditions:

1. `scope: tactical` (never `strategic`).
2. `review.revisit: true` at creation.
3. Necessary to unblock the current task (not opportunistic).
4. DECISION-NNN referenced in code or commit message.

The architect statues each unstatued tactical DECISION at the start of the next sprint via a Wave 1 task. CI rejects a sprint that closes with `review.reviewed_by: null` on a DECISION older than one sprint window.

## R3 — `## Human override` strict format

REVIEW.md `## Human override` requires 5 fields per override block:

```markdown
### Override <NNN>

- **Finding overridden:** <path:line | finding-id>
- **Reason:** <1–3 sentences>
- **Decision reference:** <DECISION-NNN | null>
- **Date:** <YYYY-MM-DD>
- **Author:** <github username or name>
```

The reviewer **never** writes in `## Human override`. `check.sh` enforces format at pre-commit and CI. A security-finding override without a `Decision reference: DECISION-NNN` is rejected.

## R4 — Marker linter and `--no-verify` audit

Two levels:

**Pre-commit (bypassable with `--no-verify` technically):**

- `// SCENARIO:` outside `pm_test_territories` → block.
- `TODO(impl-...)` malformed → block.
- DECISION authored by green without `revisit: true` or with `scope: strategic` → block.
- Zone author modified post-creation → block.
- Zone review modified without all four fields → block.
- REVIEW.md `## Human override` malformed → block.
- Security override without `Decision reference` → block.
- `mechanical:` modified without `Authored-By: architect` trailer → block.

**CI (no bypass):**

- All pre-commit checks.
- Unresolved `TODO(impl-<slug>, ...)` on a feature `done` in INDEX.md → block.
- Tactical DECISIONS not statued after one sprint window → block.
- INDEX.md ↔ reality divergence → block.
- `--no-verify` commits on the sprint window → block.
- `review.reviewed_by` modified without `Authored-By: architect` → block.
- `mechanical:` flag missing on scaffolded+ features → block.

The reviewer's pass 1 invokes `scripts/check.sh --mode ci` and treats the output as findings.

## R5 — `.features/INDEX.md` lifecycle

Status posted by the agent that **finishes** the step, never a supervisor:

| Status         | Posted by                        | When                                                   |
|----------------|----------------------------------|--------------------------------------------------------|
| `todo`         | PM (passe 1)                      | FEATURE.md drafted with narrative                      |
| `scaffolded`   | architect                         | Code scaffolded, `// AC:` inlined, `mechanical:` set    |
| `ready`        | PM (passe 2) or architect (if `mechanical: true`) | After SCENARIO inlining or directly if mechanical |
| `in-progress`  | sprint-planner                    | Feature enters active SPRINT.md                         |
| `done`         | reviewer                          | After REVIEW.md feature-level passes all three passes   |
| `blocked`      | any agent                         | When a `.blockers/` entry references the feature        |

`check.sh` verifies:

- `done` with leftover `TODO(impl-<slug>, ...)` → block.
- `ready` without scaffolding evidence (no AC markers, no `mechanical:` flag) → block.
- `in-progress` without an active SPRINT.md mentioning it → block.

## R6 — `.decisions/` zone review and `Authored-By:` trailer

Three-level defence:

1. **Pre-commit hook** — verifies YAML zone format on `.decisions/` files. Blocks creation without `revisit: true`. Blocks zone-review modification without the four fields.
2. **CI** — `git blame` on `review.reviewed_by` modifications must correspond to a commit with `Authored-By: architect`. Mismatch → CI block. Same for `mechanical:` ↔ `Authored-By: architect`.
3. **Reviewer pass 1 (DoD)** — sanity check final: iterates over commits in the sprint window touching `.decisions/`, verifies trailer ↔ zone modification consistency. Mismatch → blocking finding.

Trailer values: `architect` (architect's writes), `green` (green's tactical DECISIONS only). Never bypass with `--no-verify`.

---

# Skill loading by role

The `task-complexity-routing` skill is loaded only by agents that classify or route work:

- `product-manager` — proposes initial complexity in FEATURE.md.
- `architect` — confirms or amends complexity during DoR enrichment; sets the distinct `mechanical:` flag.
- `sprint-planner` — decides pipeline routing at planning, arbitrates upgrade disputes (type G), calibrates at retro.

The execution agents — `red`, `green`, `e2e-tester`, `reviewer`, `bug-detective` — do **not** load `task-complexity-routing`. They receive their pipeline assignment from the planner and do not make classification decisions. Loading an unnecessary skill bloats their context for no benefit.

The `agile-project` skill (this file) is loaded by **every** agent in the workflow.
