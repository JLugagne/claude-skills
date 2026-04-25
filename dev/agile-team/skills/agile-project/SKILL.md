---
name: agile-project
description: "Use this skill whenever you are working on a Go project following this agile workflow — features in .features/, sprints in .sprints/, ADRs in .adrs/, global architecture in .architecture/, per-feature ARCHITECTURE.md written by the Architect, tasks under .features/<slug>/tasks/ with scaffolding-first plus red/green triples (TASK.md shared + TASK-red.md + TASK-green.md), spec isolation between paired teammates, dispute arbitration by the sprint-planner, complexity-based agent assignment (scaffolder, red-opus/sonnet/haiku, green-opus/sonnet/haiku, e2e-tester, reviewer), PM and Architect roles for feature definition, and retro-driven sub-sprints for private-helper test coverage. Triggers: mention of sprint planning, feature breakdown, TASK.md / TASK-red.md / TASK-green.md / SCAFFOLD.md, SPRINT.md, REVIEW.md, RETRO.md, Definition of Ready, Definition of Done, blockers, questions, ADRs with revisit flag, dispute files in .disputes/, any of the sprint-planner/product-manager/architect/scaffolder/red-*/green-*/reviewer agents, agent teams, the scaffor tool, or any repository containing .features/ / .sprints/ / .adrs/ / .architecture/ directories. Also triggers for any Go file editing in such a project — all .go reads and edits must go through go-surgeon, never generic Edit/Write/Read. Consult this skill before planning a sprint, before starting any task, before writing a commit, before creating an ADR, before responding to a dispute, or whenever you need to know what artifact goes where."
---

# Agile Project Workflow

Workflow for Go projects using strict TDD, sprint-based agile, complexity-graded agents running as Claude Code teammates, scaffolding-first contracts, and spec isolation between paired teammates.

---

# Go file editing — ABSOLUTE RULE

**STRICTLY FORBIDDEN** to use `Edit`, `Write`, `Read`, or any generic tool to read or modify a `.go` file.

For **every** `.go` file without exception:

- Reading → `go-surgeon symbol` or `go-surgeon overview`
- Creation → `go-surgeon create`
- Modification → `go-surgeon patch_function`, `patch_struct`, `patch_interface`, `update`, `insert_call`, etc.

This rule applies even for a single-line change. No exceptions.

---

# Parallelization — ABSOLUTE RULE

Use **sub-agents** (`Agent` tool) or **agent teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) for any task composed of independent parts (no file conflicts, no result dependencies).

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

**When to deviate (planner's call):**

- A feature with one heavy `architectural` task and several `mechanical` tasks: split the feature across two agents (one opus, one haiku) — the heavy task does not block the easy ones.
- A scaffold-only wave: scaffolders are short-lived and cheap; running them all in parallel is fine.
- An e2e wave at sprint end: e2e tests for different features touch different test files; one agent per e2e is fine.

**What to avoid:**

- Spawning N agents where N equals task count. Pattern observed in the wild: 23 reds spawned simultaneously, 3 crashed mid-run, batch-commit lost work across all 23.
- Mixing red and green of the same task on the same agent — spec isolation breaks.
- Two agents writing to the same package concurrently (file-level races on `go-surgeon` edits).

The planner documents the chosen fan-out in `SPRINT.md` under `## Parallelization plan`, with a one-sentence rationale.

---

# Tests — ABSOLUTE RULE

Every feature **must** include:

- **Unit tests**: for any logic in `app/` and `domain/` (table-driven, mocks via interfaces).
- **Contract tests**: for each repository adapter (via testcontainers).
- **E2E / integration tests**: at least one end-to-end scenario per feature.

Tests are produced **after scaffolding and before implementation**, following the strict red/green pattern. A feature without tests is not done.

---

# Complexity classification — ABSOLUTE RULE

Every feature carries a `## Complexity` field in its `FEATURE.md`, one of `mechanical`, `standard`, `architectural`.

- Missing complexity field fails DoR.
- The planner decides pipeline routing based on this field (see *Pipeline routing by complexity* below).
- A task can be **upgraded** in complexity during execution (via dispute type G), **never downgraded** while in flight. Over-classification is corrected in the retro for future calibration, not by demoting the running task.

Detailed classification heuristics, escalation signals, and retro calibration live in the `task-complexity-routing` skill. Load that skill only when classifying, routing, or reviewing classification accuracy — not for routine implementation work.

---

# Scaffolding-first — ABSOLUTE RULE

Before red and green teammates start a feature, a **scaffolder** agent produces the **testable contract** — all exported types, interfaces, and function/method signatures with empty bodies that compile (`panic("not implemented: ...")` or zero-value returns).

- One `SCAFFOLD` task per feature. Agent: `scaffolder` (haiku).
- Scaffolder couples with the `scaffor` tool (https://github.com/JLugagne/scaffor) which generates mocks and test scaffolds from the interfaces scaffolded.
- All red tasks of the feature are `blocked by: SCAFFOLD`.
- Red tests against scaffolded signatures. Green fills in the bodies.
- **Red cannot modify scaffolded signatures.** If a signature is untestable, red raises a dispute.
- **Green cannot modify scaffolded signatures** or add new exported symbols. Green may add **private (unexported)** helpers; these must be logged in the feature retro for retroactive test coverage via a sub-sprint.

---

# Red/Green pattern — ABSOLUTE RULE

All **production-code feature work** at `standard` or `architectural` complexity follows strict TDD with **paired teammates** and **spec isolation**:

- **Red phase**: a `red-*` teammate writes failing tests against the scaffolded contract. Cannot edit production code or scaffolded signatures.
- **Green phase**: a `green-*` teammate implements scaffolded functions. Cannot edit test code, cannot modify scaffolded signatures, cannot add exported symbols.
- **Spec isolation**: red reads `TASK.md` + `TASK-red.md`. Green reads `TASK.md` + `TASK-green.md` + red's test files. Neither reads the other's private spec.
- **Dispute**: if green disagrees with red, or either disagrees with the scaffold, they open `.disputes/SPRINT_00X/<TASK_ID>.md`. The `sprint-planner` arbitrates based on public artifacts only.

All teammates (scaffolder, red, green, planner) stay **alive simultaneously** via Claude Code agent teams and communicate via teammate messaging and shared files.

Exception: scaffolder has its own standalone task (no pairing). E2E and review tasks are standalone (no red/green pairing).

## In scope vs out of scope of red/green

The rule applies to **production-code feature work**. It does **not** apply to mechanical maintenance, where there is a unique correct answer and no design decision. The frontier is:

| In scope of red/green (rule applies)                                  | Out of scope (rule does not apply)                              |
|-----------------------------------------------------------------------|-----------------------------------------------------------------|
| `standard` features (use cases, adapters, middleware, validation)     | Rename a local symbol with no API change                        |
| `architectural` features (new contracts, cross-cutting, invariants)   | `gofmt`, `goimports`, linter auto-fixes                         |
| Bug fixes that change observable behavior                             | Dependency bump with no API impact                              |
| New exported APIs, signatures, types                                  | Comment / log message / error string fixes                      |
| Behavior changes covered by acceptance criteria in `FEATURE.md`       | Regenerating mocks after an interface change already decided    |
|                                                                       | `mechanical` features (single-agent task; see *Pipeline routing*) |

The `task-complexity-routing` skill defines `mechanical` precisely as "transformation whose correct result is unique or quasi-unique" — that is exactly the zone where a red/green pair adds no signal (the test would only re-assert the input/output equality already enforced by the type system or the linter).

When in doubt, classify **upward** (`standard` over `mechanical`). Under-classification is corrected by an in-flight upgrade dispute (type G); over-classification only wastes one cheap pair.

---

# Commit cadence — ABSOLUTE RULE

Each agent **commits after every completed task**, never in batches.

- One commit per `<TASK_ID>` (one per `T00X-red`, one per `T00X-green`, one per `SCAFFOLD`, etc.).
- A teammate finishing two tasks in a row produces two commits, not one squashed commit.
- Do not defer commits to the end of a wave or the end of a sprint.

This bounds the blast radius of an agent crash, rate-limit interruption, or session loss to **one task** instead of a whole wave. The recovery procedure below depends on this.

---

# Agent crash recovery — ABSOLUTE RULE

When one or more teammates crash mid-wave (rate limit, session disconnect, OOM), follow this procedure before re-spawning. **Never** delete dirty state blindly.

## 1. Inventory dirty state

Before any cleanup decision:

- `git status` — list every modified or untracked file.
- For each dirty file, classify:
  - **complete** — the task it belongs to is finished per its DoD; safe to commit.
  - **partial** — task started, not finished; salvage decision needed.
  - **stale** — leftover from a task that was already committed elsewhere; safe to revert.
- Map dirty files → expected task scope using `SPRINT.md` and `TASKS.md`. Files outside any in-flight task scope are suspect — investigate before touching.

## 2. Salvage vs revert, per file

For each **partial** file:

- If the partial work is on a critical path of a downstream task → **salvage**: complete the minimum needed to satisfy the task DoD, then commit under the original `<TASK_ID>`.
- If the partial work is non-load-bearing or duplicates work re-spawn will redo → **revert** that specific file (`git checkout -- <path>`), not the whole tree.

For each **stale** file: revert.

For each **complete** file: commit under its `<TASK_ID>` immediately, before re-spawning anything.

## 3. Re-spawn with narrowed scope

When relaunching the crashed agents:

- Exclude every task already committed (check `git log --grep="Task:"` for the sprint).
- Exclude every task whose files were just salvaged-and-committed in step 2.
- Pass the narrowed task list explicitly in the spawn prompt — do not let the agent infer scope from `TASKS.md` alone (status fields may not yet reflect committed work).

## 4. Document the crash

Append a short entry to the sprint RETRO under `## Agent crashes` (see retro template below): which agents, which wave, which tasks salvaged vs reverted, and any lost work. This feeds the parallelization heuristic at retro time.

---

# Commits — ABSOLUTE RULE

Every commit message **must** reference feature and task:

```
<short description>

Feature: <feature-slug>
Task: <TASK_ID>
```

- `Feature:` slug under `.features/<slug>/`.
- `Task:` includes phase suffix: `SCAFFOLD`, `T003-red`, `T003-green`, `E001`, `REVIEW`, `SPRINT_REVIEW`, `H001-red` (sub-sprint helper task).
- Multiple tasks: `Task: T003-green, T004-green`.
- Maintenance: `Feature: maintenance`, `Task: -`.

Branches: `<feature-slug>/<TASK_ID>-<short-description>` (e.g., `auth/T003-green-login-usecase`, `auth/SCAFFOLD`).

---

# Push timing — ABSOLUTE RULE

A red wave produces tests that fail by design. A pre-push hook running `go test ./...` will reject these commits, and bypassing it (`--no-verify`) defeats the gate for everyone.

The rule:

- **Never push to `main` (or any shared branch with a green-tests pre-push hook) in the middle of a red wave.**
- A push to a shared branch is allowed **only** at the end of a complete green wave, when `go test ./...` passes locally.
- Within a wave, commits stay local (or on a per-feature branch) until the matching green completes.

Allowed branching strategies, pick one per project:

1. **Trunk + delayed push** (default for solo / small teams): commit red and green locally on `main`, push only when the green wave finishes.
2. **Per-feature branch + sprint-end PR**: each feature lives on `<feature-slug>` branch; red and green commits push freely there (no green-tests gate on feature branches); sprint review opens a PR to `main` once all greens are complete.

What is **not** allowed:

- `git push --no-verify` to bypass the green-tests hook during a red wave.
- A custom hook escape hatch keyed off the commit message (e.g., a `Task: T00X-red` marker that disables the hook). This was considered and rejected: it makes the hook lie about what passed, and a forgotten marker leaks broken tests to main.

Document the chosen strategy in `.architecture/CONVENTIONS.md` under a `## Branching and push timing` section.

---

# Roles summary

| Role              | Owns                                                                 | Model  |
|-------------------|---------------------------------------------------------------------|--------|
| product-manager   | `FEATURE.md` (Context, Impact functional, Acceptance criteria, Out of scope), `.features/INDEX.md` | sonnet |
| architect         | `.architecture/`, `.features/<slug>/ARCHITECTURE.md`, `.adrs/` (strategic), `FEATURE.md` sections `## Technical impact` and `## Relevant ADRs` | opus   |
| sprint-planner    | `.sprints/SPRINT_00X/SPRINT.md`, `.features/<slug>/TASKS.md`, all per-task files (`SCAFFOLD.md`, `TASK.md`, `TASK-red.md`, `TASK-green.md`), dispute decisions, sub-sprint creation | opus   |
| scaffolder        | Exported types, interfaces, signatures (empty bodies) per `ARCHITECTURE.md` | haiku  |
| red-*             | `*_test.go`, `testdata/`, `testutil/`, `mocks/` (along with `scaffor`) | haiku / sonnet / opus |
| green-*           | Non-test `.go` files (function bodies in scaffolded stubs, private helpers), tactical ADRs | haiku / sonnet / opus |
| e2e-tester        | End-to-end scenarios per feature                                    | sonnet default, opus if complex |
| reviewer          | `REVIEW.md` at feature and sprint level                             | sonnet |
| bug-detective     | On-demand bug investigation. Produces `.bugs/<bug-id>.md` reports — does not fix. Routes via planner | sonnet |

---

# Project workflow

## Principles

- Work happens in sprints. Maintenance (typos, dep updates, linting, small refactors) can happen outside sprints.
- Every non-trivial decision is documented in an ADR.
- Blockers and open questions **always** require human input — no auto-resolution. No sprint, feature, or task starts while a blocker or open question is pending.
- Red and green operate with **spec isolation**. Cross-reading private specs is forbidden.
- ADRs listed in `FEATURE.md` propagate into `SCAFFOLD.md` and `TASK.md` by the planner. All agents read the ADRs relevant to their task.

## Global architecture (.architecture/)

Owned by the **architect**. Typical contents:

- `OVERVIEW.md` — high-level architecture.
- `CONVENTIONS.md` — coding conventions, package layout, error handling, logging.
- `INTEGRATIONS.md` — external services and contracts.
- Topic-specific files as needed (`AUTH.md`, `PERSISTENCE.md`, `OBSERVABILITY.md`).

Every agent can **read** `.architecture/`. Only the architect writes.

## Features (.features/)

- `INDEX.md`: all features in priority order with status (todo / ready / in-progress / done / blocked) and complexity. Owned by the PM for priority and PM-side DoR transitions. Schema:

  ```markdown
  | Slug                | Status      | Complexity     | Priority |
  |---------------------|-------------|----------------|----------|
  | user-login          | ready       | architectural  | 1        |
  | add-email-validation| ready       | standard       | 2        |
  | rename-user-field   | ready       | mechanical     | 3        |
  ```

- `<slug>/FEATURE.md`: co-owned. PM owns Context/Impact functional/Acceptance criteria/Out of scope. Architect owns `## Technical impact`, `## Complexity` (with rationale), and `## Relevant ADRs`.
- `<slug>/ARCHITECTURE.md`: owned by the Architect. Describes the technical design for this feature: types, interfaces, package layout, dependencies, cross-cutting concerns. Primary input for the Scaffolder.

### FEATURE.md template (co-authored)

```
# Context
[PM: why this feature exists, what problem it solves]

# Impact
[PM: functional impact — which user flows change, which personas]

## Technical impact
[Architect: services/apps/packages modified, infrastructure impact]

# Acceptance criteria
- [ ] [PM: detailed testable checklist]

# Out of scope
[PM: what is NOT included]

## Complexity
`<mechanical | standard | architectural>`

## Complexity rationale
[One to three sentences explaining why this level was chosen. Reference specific characteristics: new contract introduced, pattern already exists, invariants modified, etc. Set by the Architect during DoR enrichment, with PM input.]

## Relevant ADRs
- [Architect: list of ADRs that constrain this feature's implementation]
```

### Definition of Ready (DoR)

A feature can only enter a sprint if **all** are true:

- [ ] **PM**: Context is clear and the problem is identified.
- [ ] **PM**: Acceptance criteria are testable.
- [ ] **PM**: Out of scope is explicit.
- [ ] **PM**: No open product-side question references this feature.
- [ ] **Architect**: `## Technical impact` is identified (services, packages, apps).
- [ ] **Architect**: External dependencies are listed in `ARCHITECTURE.md`.
- [ ] **Architect**: Technical risks are identified in `ARCHITECTURE.md`.
- [ ] **Architect**: No open technical question references this feature.
- [ ] **Architect**: `## Complexity` field is set to one of `mechanical`, `standard`, or `architectural` (with rationale).
- [ ] **Both**: No open blocker references this feature.

Features not satisfying DoR stay in `todo`. Only `ready` features enter a sprint.

## Tasks (.features/<slug>/TASKS.md + .features/<slug>/tasks/)

### Principle

Before a sprint starts, the `sprint-planner` agent (opus) breaks down all included features into tasks. Sprint cannot start until breakdown is complete.

### Pipeline routing by complexity

The sprint-planner routes each feature according to its `## Complexity` field (set at DoR by the Architect):

- `mechanical` → **single-agent task** with a direct `TASK.md`. No SCAFFOLD, no red/green split, no separate reviewer pass. One agent (haiku or sonnet) executes end-to-end. This is the only allowed exception to the red/green absolute rule (see *Red/Green pattern* above for the exact carve-out).
- `standard` → **reduced pipeline**: Planner → Scaffolder → Red/Green → Reviewer. Skip PM/Architect re-entry (their work is already captured in `FEATURE.md` and ADRs). Full triptyque `TASK.md` + `TASK-red.md` + `TASK-green.md` applies.
- `architectural` → **full pipeline**: PM/Architect re-entry if needed → SCAFFOLD → Red/Green → E2E → Reviewer. Mandatory strategic ADR before SCAFFOLD starts.

`SPRINT.md` documents the per-feature routing in a `## Routing decisions` section.

For classification heuristics, escalation rules, and retro calibration, the planner consults the `task-complexity-routing` skill at planning time (PM and Architect also load it, when proposing or amending complexity). Other agents (scaffolder, red, green, e2e, reviewer) inherit their assigned pipeline and do not classify.

### Task types

- **SCAFFOLD** (one per feature, first): scaffolder produces contracts.
- **Red/Green triple** (one per unit of work): three files, two agents.
- **E2E** (at least one per feature): standalone, blocked by all greens.
- **Feature REVIEW** (one per feature): blocked by all red/green/e2e.
- **Sprint REVIEW** (one per sprint): blocked by all feature REVIEWs.

### SCAFFOLD task — Definition of Done

A SCAFFOLD task is **done** only when **every** item below is verifiable. Red cannot start on a feature whose SCAFFOLD has any unchecked item. The scaffolder ticks each box in its `SCAFFOLD.md` with evidence (e.g., command output) attached.

- [ ] Every exported type listed in `ARCHITECTURE.md` exists in code.
- [ ] Every exported interface listed in `ARCHITECTURE.md` exists with all method signatures (no method bodies — interfaces only).
- [ ] Every exported constructor / factory / function listed in `ARCHITECTURE.md` exists with its signature.
- [ ] Every function body is exactly one of: `panic("not implemented: <fn>")` or a typed zero-value return. **No partial implementation.** No conditional logic, no helper calls, no early returns.
- [ ] `go build ./...` passes on the whole module (output pasted in `SCAFFOLD.md`).
- [ ] No test file is created or modified.
- [ ] Mocks are regenerated for every new interface — either by running the project's mock-generation tool, or by adding the interface to the generator's config so the next pass picks it up.
- [ ] No exported symbol exists in the diff that is not listed in `ARCHITECTURE.md` (no scope creep — new exported APIs require an architect ADR, not a scaffolder shortcut).
- [ ] `SCAFFOLD.md` checklist is fully ticked, with `go build` output and the list of new exported symbols pasted as evidence.

If any item cannot be satisfied — e.g., `ARCHITECTURE.md` lists a type the scaffolder cannot construct without designing logic — the scaffolder opens a dispute against the architect (decision E in the dispute protocol), not a partial scaffold.

### Three-file task structure (for red/green units)

Every red/green unit produces **three files** under `.features/<slug>/tasks/`:

1. **`<TASK_ID>.md`** — shared spec. Read by red, green, planner (for arbitration), reviewer.
2. **`<TASK_ID>-red.md`** — red's private spec. Read **only** by the red teammate.
3. **`<TASK_ID>-green.md`** — green's private spec. Read **only** by the green teammate.

Rules:

- Shared info goes in `TASK.md`.
- Test design goes in `TASK-red.md` only.
- Implementation design goes in `TASK-green.md` only.
- ADRs are listed in `TASK.md` `## Applicable ADRs`, not duplicated in private specs.
- Red never reads `TASK-green.md`. Green never reads `TASK-red.md`. The planner never reads either during arbitration.

### TASKS.md (task index per feature)

| ID         | Title                         | Phase    | Agent        | Status | Deps                         | Parallel |
|------------|-------------------------------|----------|--------------|--------|------------------------------|----------|
| SCAFFOLD   | Scaffolding                   | scaffold | scaffolder   | todo   | —                            | yes      |
| T001       | Login use case (shared)       | shared   | —            | —      | —                            | —        |
| T001-red   | Login use case — tests        | red      | red-sonnet   | todo   | SCAFFOLD                     | yes      |
| T001-green | Login use case — impl         | green    | green-sonnet | todo   | T001-red                     | no       |
| T002       | User repo (shared)            | shared   | —            | —      | —                            | —        |
| T002-red   | User repo contract tests      | red      | red-haiku    | todo   | SCAFFOLD                     | yes      |
| T002-green | User repo postgres adapter    | green    | green-sonnet | todo   | T002-red                     | no       |
| E001       | Login → JWT → refresh e2e     | e2e      | e2e-tester   | todo   | T001-green, T002-green       | no       |
| REVIEW     | Feature review                | review   | reviewer     | todo   | T001-green, T002-green, E001 | no       |

Unplanned tasks use `-unplanned` suffix on the phase (e.g., `T012-red-unplanned`).

Sub-sprint helper tasks use `H<NNN>-red` (no green pair, see Sub-sprints).

### Agent profiles

- `scaffolder`: always haiku. One per feature.
- `red-haiku`: mechanical tests (boilerplate, DTO validation, single file, <50 lines).
- `red-sonnet`: standard tests (use case tests, contract tests, middleware tests).
- `red-opus`: complex test design (concurrency, state machines, auth flows).
- `green-haiku`: mechanical implementation (DTOs, simple adapters, wiring).
- `green-sonnet`: standard implementation (use cases, adapters with transactions, middleware).
- `green-opus`: complex implementation (architecture, cross-cutting, concurrency, ADR-level).
- `e2e-tester`: end-to-end / integration scenarios.
- `reviewer`: always sonnet — complexity encoded in the checklist.

Red and green in the same pair are assigned **independently**. Any combination across tiers is valid: e.g., `red-opus` paired with `green-haiku`, `red-haiku` paired with `green-sonnet`, `red-sonnet` paired with `green-opus`, etc. The planner judges test-design complexity and implementation complexity as two separate decisions — a task can have hard tests but a mechanical implementation, or a trivial assertion against a concurrency-heavy implementation. No teammate should assume its partner shares its model tier; the task files (`TASKS.md` and `SPRINT.md`) are the source of truth for which specific agent is paired on each task.

### File edit permissions

Hard rule enforced by each agent's spec:

| Role       | Can edit                                                                          | Cannot edit                                                   |
|------------|-----------------------------------------------------------------------------------|---------------------------------------------------------------|
| PM         | `FEATURE.md` (Context/Impact functional/AC/Out of scope), `.features/INDEX.md`    | `.architecture/`, `.adrs/`, `ARCHITECTURE.md`, any code, any other doc |
| architect  | `.architecture/`, `.features/<slug>/ARCHITECTURE.md`, `.adrs/`, `FEATURE.md` Technical impact and Relevant ADRs sections | PM sections of FEATURE.md, `INDEX.md`, any code, tasks, sprints |
| planner    | `SPRINT.md`, `TASKS.md`, `SCAFFOLD.md`, `TASK.md` (shared), `INDEX.md`s, dispute decisions, `.questions/`, sub-sprints | `TASK-red.md`, `TASK-green.md`, any `.go` file, any ADR       |
| scaffolder | Non-test `.go` (signatures, types, empty bodies only), own `SCAFFOLD.md` DoD checkboxes, dispute file sections | `*_test.go`, test support dirs, any doc other than own spec   |
| red        | `*_test.go`, `testdata/`, `testutil/`, `mocks/`, own `TASK-red.md` DoD checkboxes, dispute file sections | Any non-test `.go`, scaffolded signatures, any doc other than own red spec |
| green      | Non-test `.go` files (fill scaffolded bodies, add private helpers), own `TASK-green.md` DoD checkboxes, dispute file sections, tactical ADRs | Any `*_test.go`, scaffolded signatures, exported symbols, any doc other than own green spec |

### ADR propagation

The architect lists relevant ADRs in `FEATURE.md` `## Relevant ADRs`. The planner propagates these into:

- `SCAFFOLD.md` `## Applicable ADRs` — ADRs affecting types, interfaces, naming, package layout.
- `TASK.md` `## Applicable ADRs` — ADRs affecting the behavior of this specific task.

Red and green read ADRs via the shared `TASK.md`. Scaffolder reads via `SCAFFOLD.md`.

### Dispute protocol

Location: `.disputes/SPRINT_00X/<TASK_ID>.md` (or `SCAFFOLD-<slug>.md`).

#### Hat-switching declaration (mono-assistant safeguard)

When a single assistant wears multiple roles in the same session (e.g., the same Claude instance acted as `red` earlier and is now arbitrating as `sprint-planner`), spec isolation is **not** enforced by the runtime — only by discipline. To make hat-switching auditable:

- Before reading any artifact in a dispute, the assistant **must** append a hat-switch marker at the top of the dispute file:

  ```markdown
  ## Planner hat activated: 2026-04-25 by <assistant-id>
  Previous hats this session: red (T003-red), green (T005-green)
  Confirms: will read only public artifacts (TASK.md, scaffolded code, test files, ADRs, ARCHITECTURE.md). Will NOT consult TASK-red.md or TASK-green.md.
  ```

- The marker is a public artifact — it stays in the dispute file and is reviewed at retro.
- Self-test before reading the *other* spec: *"Am I currently red or green? If yes, I cannot read the other private spec — I must open a dispute first and let the planner hat (mine or another's) arbitrate."*
- A dispute file missing a hat-switch marker, written by an assistant who acted as red or green earlier in the session, is treated as **invalid** at retro and the decision must be re-litigated.

This applies to **any** mono-assistant role transition, not just planner: if you wrote tests as `red-opus` and are now asked to scaffold, declare the hat switch even though scaffolding has no isolation rule — the marker creates an audit trail.

#### Red → green on the same task (mono-assistant only)

The hat-switch marker covers the case where the assistant arbitrates *another* pair's dispute. The harder case is when **the same assistant must be both red and green for the same task** — typical when agent teams aren't enabled and you're working solo.

The rule for this case:

1. The assistant **completes the red phase end to end**: writes the failing tests, runs them, confirms they fail for implementation reasons, and **commits** under `Task: <TASK_ID>-red`.
2. The assistant then **starts a fresh session** before reading `TASK-green.md`. In Claude Code this means `/clear` or opening a new conversation. The session reset is what purges `TASK-red.md` from working context.
3. The new session opens by reading **only** the green inputs: `TASK.md`, `TASK-green.md`, the test files committed in step 1, and any source files referenced. It must **not** read `TASK-red.md`.
4. The red commit is the only handoff. If green needs information that lived only in `TASK-red.md`, that is a signal the shared `TASK.md` was incomplete or the test code was insufficient — open a dispute against the planner to amend `TASK.md`, do not bypass the reset to re-read the red spec.

Audit: at sprint review, for every task where red and green were the same assistant, check `git log` — there must be **at least one commit** between the red work and the green work (the `Task: <TASK_ID>-red` commit). A task whose red and green files appear in a single commit is treated as an isolation violation.

This rule does **not** prohibit a single assistant from doing red and green on the same task. It just makes the boundary explicit, observable, and machine-checkable.

#### Who can raise



- **Scaffolder** vs architect: `ARCHITECTURE.md` ambiguous, contradictory, or incomplete.
- **Red** vs scaffolder: signature untestable.
- **Red** vs self-spec: shared spec ambiguous or contradictory.
- **Green** vs red: test unfulfilable, contradictory, over-specifying, missing-coverage, broken.
- **Green** vs scaffolder: scaffolded signature forces an untenable implementation.
- **Any teammate** vs planner: complexity-upgrade request (see *Complexity escalation* below).

Flow:

1. Disputing party creates/appends the dispute file with a structured section.
2. Disputing party messages affected teammates and the planner.
3. Work stops on the disputed portion.
4. Affected teammates may respond in their own sections — **without** reading the other's private spec.
5. The planner reads public artifacts only: shared specs, scaffolded code, test code, ADRs, `ARCHITECTURE.md`.
6. The planner writes `## Planner decision` citing only public artifacts. Decision types: A (scaffolder revises), B (red revises), C (green proceeds under interpretation), D (both adjust), E (escalate to architect), F (escalate to human), **G (complexity upgrade — see below)**.
7. **Planner notifies every teammate listed under `Action required:`** via teammate message, with a one-line summary of the decision and a pointer to the dispute file. The planner does **not** mark the dispute `Status: resolved` yet.
8. **Each notified teammate acknowledges before resuming.** Append a single line to the dispute file under a `## Acknowledgements` section:

   ```markdown
   ## Acknowledgements
   - Acknowledged by red-sonnet on 2026-04-25 — will revise tests per decision B.
   - Acknowledged by green-haiku on 2026-04-25 — will resume under interpretation C.
   ```

   Acknowledgement implies the teammate has read the planner decision and accepts the action item. A teammate that disagrees does **not** ack — it raises a new dispute (rare, only when the decision contradicts a public artifact the planner missed).

9. Once **every** teammate listed under `Action required:` has acked, the planner marks the dispute `Status: resolved` (or `awaiting-architect-input` / `awaiting-human-input` for E/F). Without all acks, the status remains `awaiting-ack`.

10. Teammates resume per decision.

Disputes persist through sprint end and feed the retro. The sprint REVIEW.md checklist rejects any dispute marked `resolved` that lacks an ack from every teammate listed in `Action required:` — incomplete propagation is treated as an unresolved dispute.

#### Complexity escalation (dispute type G)

The skill states complexity can be upgraded but never downgraded. The mechanism:

**When to raise.** A teammate (most often green or red) discovers mid-task that the work classified as `mechanical` or `standard` actually requires architectural thinking — e.g., a state machine, a concurrency invariant, a cross-cutting concern not visible from the shared spec. Telltale signs: the implementation cannot be expressed without a new abstraction; tests cannot be written without inventing a model; an ADR feels necessary.

**How to raise.** Open the dispute as type G with a target:

```markdown
## Dispute (type G — complexity upgrade)
Raised by: green-haiku on T007-green
Current classification: standard
Requested classification: architectural
Target retarget: green-haiku → green-opus

Evidence (public artifacts only):
- Scaffolded signature `CircuitBreaker.Trip()` requires a state machine with 4 states and 6 transitions; the shared TASK.md describes only "trip when threshold exceeded".
- Existing ADR-014 mentions backoff but not state ownership.
- Without a new ADR fixing state ownership, the implementation will encode an undocumented decision.
```

**Planner response.** The planner decides:

- **G-finish-then-escalate (default)**: the current agent **finishes the task** with the simplest correct implementation, commits, and the planner schedules a follow-up refactor task at the higher tier in the next sprint (or as a sub-sprint if blocking other work). This is the default because mid-task agent handoff loses context and routinely produces worse code than letting the current agent finish.
- **G-immediate-rerun**: if the current agent declares it cannot finish at all (not "can finish but suboptimally"), the planner reverts the in-progress work, re-routes the task to the higher tier, and reassigns. The reverted commit, if any, is marked in the retro.
- **G-architect-loop**: if the upgrade reveals a missing ADR, escalate to the architect first (decision E), then re-classify once the ADR exists.

**Hard rule.** Never replace `green-haiku` with `green-opus` *during* a task. Either let the haiku agent finish (then schedule follow-up refactor) or revert and restart fresh. Mid-task handoff is forbidden.

**Retro feedback.** Every G dispute is logged in `## Complexity calibration` of the RETRO. A pattern of upgrades from `standard` to `architectural` on similar tasks signals the planner is under-classifying — the calibration heuristics in `task-complexity-routing` should be tightened.

### Breakdown rules

- Tasks must be **atomic**: completable in one session with a clear DoD.
- Tasks exceeding ~1 day: split further.
- Identify **parallelizable** tasks.
- Green is **never** parallel to its own red.
- Red is always blocked by SCAFFOLD.
- Scaffold tasks of different features can run in parallel.

### Relation to other artifacts

- Blocker on a task → `.blockers/SPRINT_00X/` referencing `<feature-slug>/<TASK_ID>`.
- Question → `.questions/SPRINT_00X/` same reference.
- Non-trivial decision during green → tactical ADR under `.adrs/`.
- Dispute → `.disputes/SPRINT_00X/<TASK_ID>.md`.
- Private helper added by green → logged in feature RETRO, sub-sprint created by planner.

### Unplanned tasks

A teammate may add an unplanned task during sprint execution **without waiting for the planner**, provided **all** of the following hold:

1. The new task belongs to a feature already `in-progress` in the current sprint scope. **A new feature** cannot be unplanned — it must wait for the next sprint, or be raised as a blocker if it cannot wait.
2. The task is added to the feature's `TASKS.md` with a phase suffix `-unplanned` (e.g., `T012-red-unplanned`, `T012-green-unplanned`).
3. The task's `TASK.md` includes a `## Why unplanned` section with a one-paragraph justification: what made the work emerge mid-sprint, why it could not have been planned at sprint start, and which in-flight task it unblocks.

If writing the `## Why unplanned` justification takes more than two minutes of thought, the work is probably **not** an unplanned task — it is a blocker. Open `.blockers/SPRINT_00X/` instead and stop affected work.

The sprint-planner may, at any time during the sprint, **defer** an unplanned task: work stops on it and it moves to the next sprint's backlog. The planner cites the `## Why unplanned` paragraph in its deferral note.

At sprint review:

- Each unplanned task has its own line in `metrics.unplanned_tasks` count of the RETRO YAML.
- If `unplanned_tasks > 30 %` of `delivered_tasks`, the sprint is flagged as **under-planned** in the prose `## Dispute analysis` section, and the next sprint's planning gets an extra DoR review pass.
- Unplanned tasks that completed are folded into the regular sprint metrics (counted as delivered).
- Unplanned tasks that were deferred by the planner are listed under `## Notes the YAML can't capture` with the deferral rationale.

A new feature cannot be unplanned. Mid-sprint pivots that introduce a new feature stop the sprint and require a planner-issued blocker, not an unplanned task.

## Reviews (.features/<slug>/REVIEW.md + .sprints/SPRINT_00X/REVIEW.md)

The `reviewer` agent (sonnet) produces exhaustive verification checklists. Two levels.

### Feature-level review

Consolidates:

- Acceptance criteria from `FEATURE.md`.
- DoD items from every task of the feature (scaffold, red, green, e2e).
- Non-functional requirements.

Every item must be explicitly checked, traceable to its source, and verified with evidence.

Feature marked `done` only when REVIEW.md is fully checked.

### Sprint-level review

Aggregates feature REVIEWs plus cross-cutting:

- [ ] All feature REVIEW.md fully checked.
- [ ] Integration between features works.
- [ ] ADRs consistent with each other.
- [ ] All blockers resolved.
- [ ] All open questions answered.
- [ ] All disputes resolved, **with an `## Acknowledgements` line per teammate listed in `Action required:`**.
- [ ] All unplanned tasks documented and closed.
- [ ] Private helpers logged for sub-sprint coverage (if any).
- [ ] Global test suite green.
- [ ] `RETRO.md` YAML frontmatter present and complete (`metrics`, `helpers_added`, `crashes`, `complexity_routing`, `template_extensions`, `adrs_to_revisit`).
- [ ] Push to `main` happened only after the final green wave (no in-flight red wave on main).
- [ ] `SPRINT.md` and per-feature `TASKS.md` agree on task scope (no scope drift).
- [ ] For every task where red and green were the same assistant, `git log` shows at least one commit between the red and green work (no single combined red+green commit).

Sprint marked `done` only when sprint REVIEW.md is fully checked.

## Sprints (.sprints/)

- `INDEX.md`: all sprints with start/end dates and status.
- `SPRINT_00X/SPRINT.md`: focus, features, execution plan as todo list with agent names inline.
- `SPRINT_00X/REVIEW.md`: sprint review checklist.
- `SPRINT_00X/RETRO.md`: retrospective.
- Completion: all features done, all blockers/questions/disputes resolved, REVIEW.md fully checked, RETRO.md written, sub-sprint created if needed.
- Micro-work that can't wait: `SPRINT_00X-Y` (also the mechanism for helper-coverage sub-sprints).

### Scope: single source of truth — ABSOLUTE RULE

Sprint scope (which features and tasks are in flight) lives in **one place only**: `.sprints/SPRINT_00X/SPRINT.md`. Every other artifact references it without duplicating.

| Artifact                                  | Role re: scope                                                            |
|-------------------------------------------|---------------------------------------------------------------------------|
| `.sprints/SPRINT_00X/SPRINT.md`           | **Source of truth.** Lists features in scope, wave graph, parallelization plan, agent assignments. |
| `.features/<slug>/TASKS.md`               | Feature-local task index. Status field tracks per-task progress; **must not** restate sprint scope or wave order. Cross-references back to `SPRINT.md` by task ID. |
| `.features/INDEX.md`                      | Backlog. `status: in-progress` is set for features currently in `SPRINT.md` scope, but `INDEX.md` does not list which sprint or which tasks. |
| `.sprints/SPRINT_00X/TASKS.md` (if used)  | **Discouraged.** If created, it is a flattened view across features and is rendered from `SPRINT.md` at kickoff and frozen — never edited directly. |

Rules:

- The planner edits `SPRINT.md`. Per-feature `TASKS.md` files only update their **status** column; their task list is fixed at sprint kickoff and matches `SPRINT.md`.
- A change to scope mid-sprint (added unplanned task, descoped feature) is made in `SPRINT.md` first, then propagated to the affected `TASKS.md` — never the other way around.
- If `SPRINT.md` and a `TASKS.md` disagree on which tasks exist, `SPRINT.md` wins. Reconcile and note the divergence in the retro under `## Notes the YAML can't capture`.

A formal generator (script producing `TASKS.md` from a `scope.yaml` declaration) is **not** introduced at this stage. The duplication problem is solved by the no-duplication rule above; the generator becomes worth its maintenance cost only if drift recurs after the rule is in force. This decision is recorded — revisit at `SPRINT_00X` retro if drift is observed in `metrics.rework_commits` attributable to scope mismatch.

### Retrospective (SPRINT_00X/RETRO.md)

The retro has a **YAML frontmatter** for machine-readable metrics and helper tracking, followed by free-form prose for surprises and judgment calls. The planner parses the YAML to plan sub-sprints and trend health; humans read the prose for context.

```markdown
---
sprint: SPRINT_00X
metrics:
  planned_tasks: 56
  delivered_tasks: 54
  unplanned_tasks: 3
  disputes_raised: 4
  disputes_resolved: 4
  disputes_by_type: { A: 1, B: 0, C: 2, D: 0, E: 1, F: 0, G: 0 }
  agent_crashes: 3
  rework_commits: 13
helpers_added:
  - feature: pkg-foundation
    package: internal/natssetup/domain
    task: T001-green
    symbol: parseDuration
    file: internal/natssetup/domain/duration.go
    rationale: yaml duration strings need tolerant parser
  - feature: pkg-foundation
    package: internal/natssetup/domain
    task: T004-green
    symbol: validateStreamConfig
    file: internal/natssetup/domain/stream.go
    rationale: cross-field validation extracted from main flow
crashes:
  - wave: 3
    agents: [red-haiku, red-sonnet, red-opus]
    cause: rate-limit
    salvaged_files: 4
    reverted_files: 0
    lost_tasks: 0
adrs_to_revisit:
  - ADR-014  # backoff strategy; chose autonomously, validate after first incident
complexity_routing:
  classification_accuracy:
    correct: 12
    total: 15
  upgrades:                          # corrections actually applied (in flight or as follow-up)
    - task: T007-green
      from: standard
      to: architectural
      action: G-finish-then-escalate # or G-immediate-rerun
      follow_up: SPRINT_00X-A/T001-green
      reason: state machine emerged
  observed_downgrades:               # documented but never applied (no-downgrade-in-flight rule)
    - task: T012-green
      classified: architectural
      observed: standard
      reason: pattern was already established in adapters/
  heuristic_adjustments:
    - "resilience patterns (circuit breaker, retry, timeout) → default to architectural"
    - "single-table CRUD endpoints over an existing schema → default to mechanical"
template_extensions:
  - tool: scaffor
    template: hexagonal-go
    change: added add_shared_package command
    blocking: false
    routed_to: SPRINT_00X-tooling
---

# Sprint 00X — Retrospective

## What went well
- ...

## What caused friction
- ...

## What we change for next sprint
- [ ] actionable change 1

## Tooling issues
[links to .tools/<tool-name>/]

## Dispute analysis
[Beyond the counts in frontmatter: which spec ambiguities recurred, whether shared TASK.md needs a stricter template, etc.]

## Complexity calibration
[Per `complexity_routing` in frontmatter: narrative on the upgrades/downgrades observed and the heuristic_adjustments proposed for next sprint. Pure prose — the structured data is in the YAML.]

## Agent crashes (narrative)
[Per crashes in frontmatter: what state was lost, how recovery went, what the parallelization plan should be next sprint.]

## Notes the YAML can't capture
[Free-form. Surprises, judgment calls, weak-signal issues that don't fit a metric.]
```

#### How the planner uses this

- **Sub-sprint planning**: `helpers_added` drives the auto-creation of `SPRINT_00X-A` (helper coverage). One `H<NNN>-red` task per helper, with `task:` field as the originating commit reference.
- **Tooling sub-sprint**: `template_extensions` with `blocking: false` are batched into `SPRINT_00X-tooling`. Entries with `blocking: true` should already have been resolved as in-sprint blockers.
- **Cross-sprint health**: trends in `disputes_raised`, `agent_crashes`, and `rework_commits` are read at the start of each new sprint. Rising disputes → planner is writing vague specs. Rising crashes → fan-out is too wide.
- **Calibration**: `complexity_routing.upgrades`, `observed_downgrades`, and `heuristic_adjustments` feed the `task-complexity-routing` skill's heuristics. The retro accuracy ratio (`correct/total`) is tracked across sprints to detect drift.

A retro with prose-only (no YAML frontmatter) is **invalid** and the sprint review checklist must reject it.

## Sub-sprints (.sprints/SPRINT_00X-Y/)

Mechanism for micro-work that can't wait for a new main sprint, including **retroactive test coverage of private helpers** added by green teammates during the main sprint.

For private-helper coverage sub-sprints:

- Created by the planner after reading the main sprint's RETRO.
- Contains `H<NNN>-red` tasks (red-only, no green pair — helpers already exist).
- Tests must **pass** against existing helper implementations (exception to the normal "tests must fail" rule).
- DoD: each listed helper has tests, tests pass, coverage meets target.

Sub-sprint `SPRINT.md` cross-links back to the main sprint retro section that triggered it.

## ADRs (.adrs/)

- Strategic: multi-feature or project-direction. Written by architect.
- Tactical: feature-local. Can be written by green during implementation.
- Every ADR notes "decided autonomously" or "decided with human input".
- Every ADR has `revisit: true|false`. Autonomous decisions under uncertainty are `revisit: true` and resurface in retros.
- Superseding: never edit an existing ADR; write a new one that explicitly supersedes.

## Bugs (.bugs/)

Template: repro steps, expected, actual, root cause (once analyzed), fix (once resolved), status.

### Bug investigation flow

Bug investigation is **on-demand**, not part of a sprint plan. The flow:

1. **Trigger** — a bug is reported (CI failure, production incident, manual report, test regression).
2. **Investigation** — invoke the `bug-detective` agent. It traces the fault from `git blame` + commit trailers (`Feature: <slug>`, `Task: <TASK_ID>`) back to the originating feature, task, and ADRs.
3. **Output** — `bug-detective` writes `.bugs/<bug-id>.md` with: repro, root cause, classification (**implementation bug** = code deviates from a clear spec, vs. **spec bug** = the spec missed the case), and the originating artifacts.
4. **Routing by the planner**:
   - **Implementation bug** → planner creates a corrective red/green task (the red reproduces the bug as a failing test, green fixes). Goes into the current sprint as an unplanned task if blocking, otherwise into the next sprint backlog.
   - **Spec bug** → planner opens a `.questions/` for PM or Architect (depending on whether the gap is functional or technical), then re-plans once the spec is amended.
5. **Closure** — bug status moves to `resolved` when the corrective task ships. The bug file links to the corrective `<TASK_ID>` for traceability.

`bug-detective` is **post-mortem**: it reads `TASK-red.md` and `TASK-green.md` freely (the work is committed and isolation no longer applies). It does **not** participate in any live dispute — its output is a structured report, not an arbitration argument. If the bug investigation reveals a contradiction between red and green specs, `bug-detective` flags it in the report; the planner decides whether to open a retrospective dispute or simply route the fix.

The agent file is `agents/bug-detective.md`.

## Blockers (.blockers/SPRINT_00X/)

- Multiple solutions as checklist.
- **Always require human input**. Affected teammates stop.

## Questions (.questions/SPRINT_00X/)

A single folder per sprint. Phase is captured **in the file's frontmatter**, not in the folder name — three folders (PREP, PLANNING, 00X) was rejected as too coarse.

```markdown
---
id: Q069
phase: planning              # one of: prep | planning | execution
raised_by: architect
raised_on: 2026-04-22
references: [user-login, T003]
blocking_scope: planning     # one of: feature-DoR | sprint-kickoff | task | none
---

# Question
[the actual question]

## Suggested resolutions
- [ ] option A — ...
- [ ] option B — ...

## Answer
[free text, written by the human or, for technical-only questions, by the architect]
```

#### Phase semantics

| `phase`    | When raised                                | Default `blocking_scope`           | Resolution deadline    |
|------------|--------------------------------------------|-----------------------------------|------------------------|
| `prep`     | While drafting FEATURE.md / DoR check      | `feature-DoR`                     | Before the feature reaches `ready` |
| `planning` | While the planner authors SPRINT.md / TASKS.md | `sprint-kickoff`              | Before sprint kickoff   |
| `execution`| Mid-sprint, while a task is in flight       | `task` (default) or `sprint`      | Before the dependent task closes (or sprint, if scope=sprint) |

Rules:

- A `prep` question blocks only the feature it references — other features can still ship.
- A `planning` question blocks **the entire sprint kickoff** until resolved. Sprint cannot start with open `planning` questions.
- An `execution` question with `blocking_scope: task` blocks only that task. Other tasks proceed. The task is not closed until the question has an answer.
- An `execution` question with `blocking_scope: sprint` (rare; e.g., reveals a missing ADR) blocks all dependent work and triggers a planner pause.

- **Always require human input**. Exception: architect can answer technical questions raised by teammates (dispute decision E).

## Disputes (.disputes/SPRINT_00X/)

- One file per disputed task.
- Sections: raising party's dispute, paired teammate's response, planner's decision.
- Planner decides based on public artifacts only.
- Resolved disputes stay for retro analysis.

## Tooling feedback (.tools/<tool-name>/)

Create folder for any tool causing friction. Report as bug or friction-with-improvement-suggestion.

Key tooling in this project:

- **go-surgeon**: mandatory for all `.go` file operations.
- **scaffor** (github.com/JLugagne/scaffor): generates mocks and test scaffolds from scaffolded interfaces. Runs after the scaffolder completes.

### Template evolution (scaffor and similar)

Scaffor templates (and any other generator template under `.scaffor-templates/`) are project-wide assets. Extending them — new commands, new variables, fixed `shell_commands` — is cross-sprint work that the agile workflow handles in two distinct ways depending on whether the extension is **blocking the current sprint**:

- **Blocking extension** — the current sprint cannot proceed without the new command/variable (e.g., the planner wrote a SCAFFOLD task that requires `add_shared_package`, which doesn't exist yet). Treat as an in-sprint blocker:
  - File it under `.blockers/SPRINT_00X/template-<name>.md`.
  - Affected scaffold tasks stop until the extension lands.
  - Extension lives on the same branch as the dependent feature, committed with `Feature: maintenance`, `Task: tooling-<short>`.

- **Non-blocking extension** — the extension would improve future sprints but the current one has a workable detour (manual scaffold, smaller signature). Route to the tooling sub-sprint:
  - Log under `template_extensions:` in the RETRO YAML frontmatter with `blocking: false`.
  - Planner aggregates non-blocking entries into `SPRINT_00X-tooling` after retro.
  - Tooling sub-sprint has no red/green pairing — it's scaffolder + reviewer only (template manifest authoring + a `scaffor lint` + `scaffor test` gate).

Reject the third option of "edit the template inline mid-task without a record" — template drift across sprints causes silent regressions in scaffolds nobody attributes to the template change.

---

## Skill loading by role

The `task-complexity-routing` skill is loaded only by agents that classify or route work:

- `product-manager` — proposes initial complexity in `FEATURE.md`.
- `architect` — confirms or amends complexity during DoR enrichment.
- `sprint-planner` — decides pipeline routing at planning, arbitrates upgrade disputes (type G), calibrates at retro.

The execution agents — `scaffolder`, `red-*`, `green-*`, `e2e-tester`, `reviewer`, `bug-detective` — do **not** load `task-complexity-routing`. They receive their pipeline assignment from the planner and do not make classification decisions. Loading an unnecessary skill bloats their context for no benefit.

The `agile-project` skill (this file) is loaded by **every** agent in the workflow.
