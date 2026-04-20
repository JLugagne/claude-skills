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

---

# Tests — ABSOLUTE RULE

Every feature **must** include:

- **Unit tests**: for any logic in `app/` and `domain/` (table-driven, mocks via interfaces).
- **Contract tests**: for each repository adapter (via testcontainers).
- **E2E / integration tests**: at least one end-to-end scenario per feature.

Tests are produced **after scaffolding and before implementation**, following the strict red/green pattern. A feature without tests is not done.

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

All implementation work follows strict TDD with **paired teammates** and **spec isolation**:

- **Red phase**: a `red-*` teammate writes failing tests against the scaffolded contract. Cannot edit production code or scaffolded signatures.
- **Green phase**: a `green-*` teammate implements scaffolded functions. Cannot edit test code, cannot modify scaffolded signatures, cannot add exported symbols.
- **Spec isolation**: red reads `TASK.md` + `TASK-red.md`. Green reads `TASK.md` + `TASK-green.md` + red's test files. Neither reads the other's private spec.
- **Dispute**: if green disagrees with red, or either disagrees with the scaffold, they open `.disputes/SPRINT_00X/<TASK_ID>.md`. The `sprint-planner` arbitrates based on public artifacts only.

All teammates (scaffolder, red, green, planner) stay **alive simultaneously** via Claude Code agent teams and communicate via teammate messaging and shared files.

Exception: scaffolder has its own standalone task (no pairing). E2E and review tasks are standalone (no red/green pairing).

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

- `INDEX.md`: all features in priority order with status (todo / ready / in-progress / done / blocked). Owned by the PM for priority and PM-side DoR transitions.
- `<slug>/FEATURE.md`: co-owned. PM owns Context/Impact functional/Acceptance criteria/Out of scope. Architect owns `## Technical impact` (appended) and `## Relevant ADRs`.
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
- [ ] **Both**: No open blocker references this feature.

Features not satisfying DoR stay in `todo`. Only `ready` features enter a sprint.

## Tasks (.features/<slug>/TASKS.md + .features/<slug>/tasks/)

### Principle

Before a sprint starts, the `sprint-planner` agent (opus) breaks down all included features into tasks. Sprint cannot start until breakdown is complete.

### Task types

- **SCAFFOLD** (one per feature, first): scaffolder produces contracts.
- **Red/Green triple** (one per unit of work): three files, two agents.
- **E2E** (at least one per feature): standalone, blocked by all greens.
- **Feature REVIEW** (one per feature): blocked by all red/green/e2e.
- **Sprint REVIEW** (one per sprint): blocked by all feature REVIEWs.

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

Red and green in the same pair can receive **different** agents — complexity is judged independently.

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

Who can raise:

- **Scaffolder** vs architect: `ARCHITECTURE.md` ambiguous, contradictory, or incomplete.
- **Red** vs scaffolder: signature untestable.
- **Red** vs self-spec: shared spec ambiguous or contradictory.
- **Green** vs red: test unfulfilable, contradictory, over-specifying, missing-coverage, broken.
- **Green** vs scaffolder: scaffolded signature forces an untenable implementation.

Flow:

1. Disputing party creates/appends the dispute file with a structured section.
2. Disputing party messages affected teammates and the planner.
3. Work stops on the disputed portion.
4. Affected teammates may respond in their own sections — **without** reading the other's private spec.
5. The planner reads public artifacts only: shared specs, scaffolded code, test code, ADRs, `ARCHITECTURE.md`.
6. The planner writes `## Planner decision` citing only public artifacts. Decision types: A (scaffolder revises), B (red revises), C (green proceeds under interpretation), D (both adjust), E (escalate to architect), F (escalate to human).
7. Teammates resume per decision. Dispute marked `Status: resolved` (or `awaiting-architect-input` / `awaiting-human-input`).

Disputes persist through sprint end and feed the retro.

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
- [ ] All disputes resolved.
- [ ] All unplanned tasks documented and closed.
- [ ] Private helpers logged for sub-sprint coverage (if any).
- [ ] Global test suite green.

Sprint marked `done` only when sprint REVIEW.md is fully checked.

## Sprints (.sprints/)

- `INDEX.md`: all sprints with start/end dates and status.
- `SPRINT_00X/SPRINT.md`: focus, features, execution plan as todo list with agent names inline.
- `SPRINT_00X/REVIEW.md`: sprint review checklist.
- `SPRINT_00X/RETRO.md`: retrospective.
- Completion: all features done, all blockers/questions/disputes resolved, REVIEW.md fully checked, RETRO.md written, sub-sprint created if needed.
- Micro-work that can't wait: `SPRINT_00X-Y` (also the mechanism for helper-coverage sub-sprints).

### Retrospective (SPRINT_00X/RETRO.md)

```
# Sprint 00X — Retrospective

## What went well
- ...

## What caused friction
- ...

## What we change for next sprint
- [ ] actionable change 1

## Tooling issues
[links to .tools/<tool-name>/]

## ADRs to revisit
[ADRs with revisit: true]

## Dispute summary
[count, patterns, whether recurring spec ambiguity should change planner behavior]

## Agent assignment accuracy
[over/under-assignments observed; feeds future planning]

## Private helpers added (per feature)

### <feature-slug>
- `package/file.go::helperName1` — added during T001-green, rationale: <short>
- `package/file.go::helperName2` — added during T003-green, rationale: <short>

[Planner reads this section and creates SPRINT_00X-Y sub-sprint for coverage.]
```

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

## Blockers (.blockers/SPRINT_00X/)

- Multiple solutions as checklist.
- **Always require human input**. Affected teammates stop.

## Questions (.questions/SPRINT_00X/)

- Multiple suggestions + free text answer.
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

---

## Add to the list of absolute rules

```markdown
# Complexity classification — ABSOLUTE RULE

Every feature carries a `complexity` field in its FEATURE.md, one of:
`mechanical`, `standard`, `architectural`.

- Missing complexity field fails DoR.
- The planner decides pipeline routing based on complexity.
- A task can be upgraded in complexity during execution (via dispute/blocker),
  but never downgraded.

Detailed classification heuristics, escalation signals, and retro calibration
live in the `task-complexity-routing` skill. Load that skill only when
classifying, routing, or reviewing classification accuracy.
```

## Add to the FEATURE.md template

In the existing template, after `## Out of scope`:

```markdown
## Complexity
`<mechanical | standard | architectural>`

## Complexity rationale
[One to three sentences explaining why this level was chosen. Reference
specific characteristics: new contract introduced, pattern already exists,
invariants modified, etc.]
```

---

## Add to the INDEX.md template for .features

Extend the feature table:

```markdown
| Slug | Status | Complexity | Priority |
|------|--------|------------|----------|
| user-login | ready | architectural | 1 |
| add-email-validation | ready | standard | 2 |
| rename-user-field | ready | mechanical | 3 |
```

---

## Add to the pipeline routing documentation

In the lifecycle section of the skill:

```markdown
## Pipeline routing by complexity

The sprint-planner routes each feature according to its complexity:

- `mechanical` → single-agent task with direct TASK.md. No PM, Architect,
  Scaffolder, or red/green split.
- `standard` → reduced pipeline: Planner → Scaffolder → Red/Green → Reviewer.
  Skip PM and Architect re-entry (their work is already captured in
  FEATURE.md and ADRs).
- `architectural` → full pipeline as described above, with mandatory
  strategic ADR.

The SPRINT.md documents routing decisions per feature in the
`## Routing decisions` section.

For classification rules, escalation signals, and retro feedback format,
the sprint-planner loads the `task-complexity-routing` skill at planning
time.
```

---

## Add to the DoR list

Extend the existing DoR gate:

```markdown
## DoR gate

Include a feature in the sprint only if its DoR is fully satisfied:

- Feature status is `ready` in `.features/INDEX.md`.
- No open blocker references the feature.
- No open question references the feature.
- `ARCHITECTURE.md` exists and the `## Relevant ADRs` section in FEATURE.md
  is present (even if empty).
- **`## Complexity` field in FEATURE.md is set to one of mechanical,
  standard, or architectural.**

If a feature fails DoR: exclude it, report explicitly, move on.
```

---

## Agents that need the `task-complexity-routing` skill

Add `task-complexity-routing` to the `requires_skills` list of:

- `product-manager` (proposes initial complexity)
- `architect` (confirms or amends at DoR)
- `sprint-planner` (decides pipeline routing, handles escalations, calibrates at retro)

Do NOT add it to: `scaffolder`, `red-*`, `green-*`, `e2e-tester`, `reviewer`.
These agents receive their pipeline assignment from the planner and do not
make classification decisions.
