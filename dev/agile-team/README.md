---
description: "Claude Code agent team and workflow for Go projects: strict TDD with paired red/green teammates, scaffolding-first contracts, spec isolation, dispute arbitration, and complexity-graded model assignment across PM, Architect, Scaffolder, Red, Green, E2E and Reviewer roles."
tags:
  - claude-code
  - agent-team
  - go
  - golang
  - tdd
  - red-green
  - sprint-planning
  - agile
  - scaffolding
  - adr
  - sub-agents
  - workflow
---

# Agile Go Project — Agent Team

A Claude Code agent team and workflow for Go projects. Enforces strict TDD, spec isolation between paired teammates, scaffolding-first contracts, and complexity-graded model assignment.

## What this is

A set of Claude Code sub-agents plus a `skill` that defines how they work together. Together they cover the full lifecycle of a feature — from product definition to shipped, tested, reviewed code — with clear handoffs, read/write permissions per role, and dispute resolution when teammates disagree.

The design favors **explicit contracts** over coordination: every agent knows exactly what to read, what to edit, and what to hand off. Disputes are first-class artifacts, not a failure mode.

## Why this setup

Typical LLM coding workflows conflate roles: a single agent drafts requirements, designs architecture, writes tests, writes implementation, and reviews itself. That works for small changes but degrades on real features:

- Tests get written **after** implementation and test what was built rather than what was required.
- Architectural decisions stay implicit, then resurface as refactors.
- One agent's fatigue on task N+1 causes regressions on task N.
- Complex features get the same model as trivial ones — either overpaying or under-delivering.

This workflow separates these concerns into explicit roles, with paired teammates running **simultaneously** and challenging each other via Claude Code agent teams. The sprint planner decomposes work, a scaffolder produces the testable contract, red writes tests against that contract, green implements — and each can raise a dispute the planner arbitrates.

## Repository layout

```
.claude/
  agents/
    product-manager.md    — PM role (sonnet)
    architect.md          — Architect role (opus)
    sprint-planner.md     — Sprint planning + dispute arbitration (opus)
    scaffolder.md         — Produces testable contracts (haiku)
    red-haiku.md          — Red-phase TDD, mechanical tests (haiku)
    red-sonnet.md         — Red-phase TDD, standard tests (sonnet)
    red-opus.md           — Red-phase TDD, complex tests (opus)
    green-haiku.md        — Green-phase TDD, mechanical impl (haiku)
    green-sonnet.md       — Green-phase TDD, standard impl (sonnet)
    green-opus.md         — Green-phase TDD, complex impl (opus)
    e2e-tester.md         — End-to-end / integration scenarios (sonnet, opus on demand)
    reviewer.md           — Feature and sprint REVIEW.md authoring (sonnet)
    bug-detective.md      — On-demand bug investigation, produces .bugs/ reports (sonnet)

skills/
  agile-project/SKILL.md         — Workflow definition, auto-triggers for matching projects
  task-complexity-routing/SKILL.md — Classification heuristics, loaded by PM/Architect/Planner only
```

Project artifacts (created and maintained by the agents in your Go repo):

```
.features/
  INDEX.md                          — backlog with status per feature
  <slug>/
    FEATURE.md                      — co-authored by PM and Architect
    ARCHITECTURE.md                 — Architect's technical design
    REVIEW.md                       — feature-level verification checklist
    TASKS.md                        — task index
    tasks/
      SCAFFOLD.md                   — scaffolder's task
      <TASK_ID>.md                  — shared spec (read by red and green)
      <TASK_ID>-red.md              — red's private spec
      <TASK_ID>-green.md            — green's private spec

.sprints/
  INDEX.md
  SPRINT_00X/
    SPRINT.md                       — execution plan with agents inline
    REVIEW.md                       — sprint-level checklist
    RETRO.md                        — retrospective
  SPRINT_00X-Y/                     — sub-sprints (e.g., helper coverage)

.architecture/
  OVERVIEW.md, CONVENTIONS.md, INTEGRATIONS.md, ...

.adrs/
  <NNN>-<slug>.md                   — strategic and tactical ADRs

.blockers/SPRINT_00X/               — issues requiring human input
.questions/SPRINT_00X/              — open questions, same
.disputes/SPRINT_00X/               — teammate disagreements
.bugs/                              — bug reports
.tools/<tool-name>/                 — tooling friction reports
```

## Roles at a glance

| Role              | Model  | Owns                                                         | Can edit                                                       |
|-------------------|--------|--------------------------------------------------------------|----------------------------------------------------------------|
| product-manager   | sonnet | the **what** and **why**                                     | PM sections of `FEATURE.md`, `INDEX.md`                        |
| architect         | opus   | the **how** at project and feature level                     | `.architecture/`, `ARCHITECTURE.md`, `.adrs/`, tech sections of `FEATURE.md` |
| sprint-planner    | opus   | sprint plan, task specs, arbitration                         | `SPRINT.md`, `TASKS.md`, shared `TASK.md`, `SCAFFOLD.md`, dispute decisions |
| scaffolder        | haiku  | testable contract (types, interfaces, empty-body signatures) | non-test `.go` files (signatures only)                         |
| red-\*            | varies | failing tests against the scaffolded contract                | `*_test.go`, `testdata/`, `testutil/`, `mocks/`                |
| green-\*          | varies | implementation filling scaffolded bodies                     | non-test `.go` files (bodies, private helpers only)            |
| e2e-tester        | varies | end-to-end scenarios                                         | integration test files                                         |
| reviewer          | sonnet | feature and sprint REVIEW checklists                         | `REVIEW.md` files only                                         |
| bug-detective     | sonnet | post-mortem bug investigation (on-demand, not in sprint)     | `.bugs/<bug-id>.md` only — never fixes code, routes via planner |

## The lifecycle of a feature

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. PM drafts FEATURE.md                                             │
│    → Context, functional Impact, Acceptance criteria, Out of scope  │
│    → Status: todo                                                   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Architect enriches                                               │
│    → Creates ARCHITECTURE.md                                        │
│    → Writes strategic ADRs if needed                                │
│    → Appends Technical impact + Relevant ADRs to FEATURE.md         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. PM + Architect verify DoR jointly                                │
│    → PM items: context, testable AC, out of scope                   │
│    → Architect items: technical impact, deps, risks                 │
│    → Status: ready                                                  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. Sprint-planner plans the next sprint                             │
│    → Breaks feature into SCAFFOLD + red/green triples + e2e         │
│    → Assigns agents by complexity                                   │
│    → Propagates ADRs from FEATURE.md into SCAFFOLD.md and TASK.md   │
│    → Writes SPRINT.md execution plan                                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. Scaffolder runs                                                  │
│    → Produces types, interfaces, empty-body signatures              │
│    → `scaffor` generates mocks and test scaffolds                   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. Red and green teammates run as a team                            │
│    → Red writes failing tests (reads TASK.md + TASK-red.md)         │
│    → Green fills in (reads TASK.md + TASK-green.md + test files)    │
│    → Either can raise disputes → planner arbitrates on public specs │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 7. E2E + reviews                                                    │
│    → e2e-tester writes integration scenarios                        │
│    → reviewer produces feature REVIEW.md                            │
│    → reviewer produces sprint REVIEW.md                             │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 8. Retrospective                                                    │
│    → Private helpers added by green → sub-sprint for test coverage  │
│    → ADRs marked `revisit: true` surface for next sprint            │
│    → Agent assignment accuracy feedback                             │
└─────────────────────────────────────────────────────────────────────┘
```

## Core mechanics

### Scaffolding-first

Before red and green start, a `scaffolder` agent produces the **testable contract** of the feature from `ARCHITECTURE.md`: all exported types, interfaces, and function signatures with empty bodies that compile (`panic("not implemented")` or zero returns).

This matters because:

- Red writes tests **against a real contract**, not against imagined APIs.
- Green cannot drift from the agreed shape — signatures are frozen.
- `scaffor` (https://github.com/JLugagne/scaffor) generates mocks and test skeletons from the scaffolded interfaces automatically.

Red can dispute a scaffolded signature if it's untestable. Green can dispute if it forces a bad implementation. Both are routed to the planner.

### Red/Green with spec isolation

Every unit of work produces **three files**:

| File                | Readable by                  | Content                           |
|---------------------|------------------------------|-----------------------------------|
| `<TASK_ID>.md`      | red, green, planner, reviewer | shared spec, acceptance criteria, applicable ADRs |
| `<TASK_ID>-red.md`  | red only                     | test cases to write, red's DoD    |
| `<TASK_ID>-green.md`| green only                   | implementation constraints, green's DoD |

Rules:

- Red **cannot** read green's spec.
- Green **cannot** read red's spec, but **can** read the test files red produced — those are the contract.
- The planner **cannot** read either private spec during arbitration — decisions rest on shared artifacts only.

Why this matters: it forces the planner to write unambiguous shared specs. If red and green cannot converge from the shared spec alone, the spec was the problem, not one of the teammates.

### Dispute arbitration

When two teammates disagree, the dispute is materialized as a file in `.disputes/SPRINT_00X/<TASK_ID>.md`. Either party writes its reasoning; the other may respond.

The planner reads the dispute, the shared spec, and the relevant code (tests or scaffold) — never the private specs. Then writes a decision citing only public artifacts.

Decision types:

- **A**: scaffolder revises
- **B**: red revises
- **C**: green proceeds under a specific interpretation
- **D**: both adjust
- **E**: escalate to architect (dispute reveals gap in `ARCHITECTURE.md` or ADRs)
- **F**: escalate to human (genuine product ambiguity)
- **G**: complexity upgrade — current agent finishes the task at its tier, planner schedules a follow-up refactor at the higher tier (mid-task agent handoff is forbidden)

The planner notifies impacted teammates and waits for an `## Acknowledgements` line per teammate before flipping the dispute to `resolved`. A dispute resolved without acks is treated as unresolved at sprint review.

### Crash recovery

When teammates crash mid-wave (rate limit, session loss), the procedure is: inventory dirty state via `git status`, classify each file as complete / partial / stale, salvage the partials worth saving and revert the rest, then re-spawn with a narrowed task list. The per-task commit cadence (rule 7) bounds the loss to one task. The crash is logged in the RETRO YAML `crashes:` block to feed the parallelization heuristic.

### Push timing and branching

A red wave produces failing tests by design. Pushing to a branch with a green-tests pre-push hook during a red wave is forbidden. Two strategies are documented and supported: trunk + delayed push (commit locally, push at end of green), or per-feature branch + sprint-end PR. The chosen strategy lives in `.architecture/CONVENTIONS.md`.

### Scope as a single source of truth

`SPRINT.md` is the only artifact that defines the sprint's scope. Per-feature `TASKS.md` only tracks status — it does not redeclare scope. A scope change mid-sprint is made in `SPRINT.md` first, then propagated. A formal generator (`scope.yaml` → `TASKS.md`) was considered and deferred until the no-duplication rule proves insufficient.

### Complexity-based agent assignment

The planner judges each task's complexity independently and picks an agent:

| Agent          | When                                                    |
|----------------|---------------------------------------------------------|
| `red-haiku`    | mechanical tests (DTO validation, boilerplate)          |
| `red-sonnet`   | standard tests (use case tests, contract tests)         |
| `red-opus`     | complex design (concurrency, state machines, auth)      |
| `green-haiku`  | mechanical impl (wiring, simple adapters)               |
| `green-sonnet` | standard impl (use cases, middleware)                   |
| `green-opus`   | complex impl (architecture, cross-cutting, concurrency) |

Red and green in the same pair can have **different** agents — judged independently. If in doubt, the planner promotes to opus: under-assignment forces mid-task handoff, which is worse than over-paying.

The retro includes an "Agent assignment accuracy" section to calibrate over time.

### Private helpers and sub-sprints

Green **may** add private (unexported) functions to decompose complex logic. It **may not** add exported symbols — those are the scaffolder's job.

Every private helper added must be listed in the feature's retro under `## Private helpers added`. The planner reads this at retro processing and creates a sub-sprint `SPRINT_00X-Y` containing `H<NNN>-red` tasks — red-only tasks that retroactively cover each helper with tests.

This is the one place tests must **pass** (not fail) against existing code — the helpers already exist, tests validate them.

### ADR flow

- Strategic ADRs are written by the architect during feature enrichment.
- Tactical ADRs can be written by green during implementation when a non-trivial decision is made.
- Every ADR has a `revisit: true|false` flag. Autonomous decisions under uncertainty get `revisit: true` and resurface in retros.
- The architect lists relevant ADRs in `FEATURE.md` `## Relevant ADRs`.
- The planner propagates them into `SCAFFOLD.md` and `TASK.md` `## Applicable ADRs`.
- Scaffolder, red, and green read the ADRs applicable to their task.

## Hard rules the project enforces

These are absolute and documented in the `agile-project` skill:

1. **Go file editing**: all `.go` reads and edits via `go-surgeon`. Never generic Edit/Write/Read.
2. **Parallelization**: independent work launches in parallel (sub-agents or agent teams), never sequentially. Default fan-out granularity is **one agent per feature**, not one agent per task.
3. **Tests**: unit + contract + e2e, produced before implementation via red/green.
4. **Complexity classification**: every feature carries `mechanical | standard | architectural` set at DoR. The pipeline runs differently per level (red/green only applies to `standard` and `architectural`).
5. **Scaffolding-first**: no red or green starts before SCAFFOLD is done. SCAFFOLD has a strict 9-item DoD that red can verify itself.
6. **Red/green pattern**: strict TDD with paired teammates, spec isolation, planner arbitration. When a single assistant must be both red and green, a session reset (`/clear`) and a committed red boundary are mandatory.
7. **Commits**: one commit per task, message references `Feature: <slug>` and `Task: <TASK_ID>`. No batch commits across tasks (bounds crash blast radius).
8. **Push timing**: never push to `main` (or any branch with a green-tests pre-push hook) during a red wave. `--no-verify` to bypass is forbidden.
9. **Scope single source of truth**: `SPRINT.md` is the only artifact that defines sprint scope. Per-feature `TASKS.md` references it without duplicating.
10. **Disputes**: every planner decision is acknowledged by impacted teammates in the dispute file before the dispute closes.
11. **Blockers and questions**: always require human input. No auto-resolution.

## Getting started

### Prerequisites

- Claude Code `v2.1.32+` for agent teams.
- Agent teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your `settings.json` or environment.
- `go-surgeon` installed and available in your environment.
- `scaffor` (https://github.com/JLugagne/scaffor) installed if you want automatic mock and test scaffold generation.

### Installation

1. Copy `.claude/agents/*.md` to your project's `.claude/agents/` directory.
2. Copy the `agile-project/` skill folder to a skill location recognized by Claude Code (project `.claude/skills/` or user-level).
3. Create the initial directory layout in your repo:
   ```bash
   mkdir -p .features .sprints .architecture .adrs .blockers .questions .disputes .bugs .tools
   touch .features/INDEX.md .sprints/INDEX.md
   ```
4. Have the architect draft initial `.architecture/OVERVIEW.md` and `.architecture/CONVENTIONS.md`.

### First feature

```
# Drafting
> Invoke product-manager to draft FEATURE "user-login"
> Invoke architect to enrich FEATURE "user-login"
> Both verify DoR, set status to ready

# Planning and execution
> Invoke sprint-planner to plan the next sprint
> Start the sprint (run the execution plan from SPRINT.md as an agent team)

# Review
> When execution finishes, reviewer agents produce REVIEW.md
> Write RETRO.md
> Planner processes retro for sub-sprint creation if needed
```

## Known limitations

- **Agent teams are experimental**. Session resumption (`/resume`, `/rewind`) does not restore teammates. Task status can lag. Shutdown can be slow. See the [Claude Code agent teams docs](https://code.claude.com/docs/en/agent-teams) for the full list.
- **Spec isolation is auto-disciplined**. Claude Code does not enforce file-read restrictions technically — agents respect the rules because their specs instruct them to. If you need hard enforcement, a `PreToolUse` hook filtering reads by agent name and path is the recommended addition.
- **PM and Architect can both edit `FEATURE.md`** on different sections. Running them sequentially avoids conflicts; running them simultaneously is possible but requires care.
- **Sub-sprint mechanics require discipline from green** — a green teammate that forgets to log a private helper in the RETRO YAML `helpers_added:` breaks the coverage loop. The feature REVIEW.md checklist includes a verification step to catch this; the green agent specs grant an explicit append-only exception on `RETRO.md` for this purpose.
- **Mono-assistant red→green** is allowed but requires a session reset (`/clear` or new conversation) and a committed `Task: <TASK_ID>-red` boundary before reading the green spec. Verifiable via `git log` at sprint review. Agent teams remove this constraint; it only applies when running solo without the experimental teams flag.
- **`bug-detective` is on-demand**, not part of a sprint plan. It is invoked manually when a bug is reported; its output (`.bugs/<bug-id>.md`) is then routed by the planner into a corrective task or a spec question.

## File-by-file reference

### Skills

- **`skills/agile-project/SKILL.md`** — the workflow definition. Auto-triggers in any project matching the described structure. Every agent loads it via Claude Code's skill mechanism.
- **`skills/task-complexity-routing/SKILL.md`** — classification heuristics for `mechanical | standard | architectural`. Loaded only by `product-manager`, `architect`, and `sprint-planner` (the agents that classify or route).

### Agents

- **`product-manager.md`** (sonnet) — owns product definition. Writes PM-owned sections of `FEATURE.md` and `INDEX.md`, proposes initial complexity. Never touches code or architecture.

- **`architect.md`** (opus) — owns technical design. Writes `.architecture/`, per-feature `ARCHITECTURE.md`, strategic ADRs, and the technical sections of `FEATURE.md` including `## Complexity` (with rationale).

- **`sprint-planner.md`** (opus) — owns planning, routing, and arbitration. Breaks features into tasks, picks the pipeline by complexity, assigns agents, arbitrates disputes (types A–G) on public artifacts only, creates sub-sprints from retro YAML.

- **`scaffolder.md`** (haiku) — produces testable contracts. Strict 9-item DoD ensures red can verify scaffold completion without asking the planner. Disputes against the architect when `ARCHITECTURE.md` is ambiguous.

- **`red-haiku.md`** / **`red-sonnet.md`** / **`red-opus.md`** — writes failing tests at three complexity tiers. Reads shared spec + own red spec + test files in the same package. Never reads green's spec or edits production code.

- **`green-haiku.md`** / **`green-sonnet.md`** / **`green-opus.md`** — fills scaffolded bodies at three tiers. Reads shared spec + own green spec + red's test files. Mono-assistant safeguard: a session reset is required if the same instance authored the red work earlier in the session.

- **`e2e-tester.md`** (sonnet, opus on demand) — writes integration scenarios after every red/green pair completes. Drives features through real entry points against testcontainers. Inherits red's isolation rules (no private spec reads).

- **`reviewer.md`** (sonnet) — produces feature and sprint REVIEW.md. Post-mortem reads everything (including private specs) but writes only REVIEW files. Verifies every checklist item with concrete evidence (test output, file path, commit hash).

- **`bug-detective.md`** (sonnet, on-demand) — investigates reported bugs, classifies as implementation vs. spec bug, writes `.bugs/<bug-id>.md`. Does not fix — routes via planner.

## Design rationale

A few choices that may look unusual:

- **Scaffolder as a separate haiku agent rather than a "green preparing the ground"**: keeps the red/green phases free of contract decisions, which are architectural. Haiku suffices because the work is mechanical — the hard thinking happened in `ARCHITECTURE.md`.

- **Spec isolation between red and green**: forces the planner to produce precise shared specs. If red and green can't agree from the shared spec, the spec has a gap. This surfaces planning bugs early.

- **Disputes as artifacts instead of runtime conversations**: survivable across session resumption, reviewable in retros, forces structured argument (each party states its position with citation), and provides training data for future planning.

- **Private helpers via sub-sprint retro loop**: lets green stay productive (decompose complex functions) without bloating the main sprint plan. The coverage debt is explicit and bounded.

- **Complexity-graded models with bias toward opus in doubt**: real tasks vary by 10x in difficulty; forcing everything through one model wastes cost or quality. Bias to opus on uncertainty avoids mid-task handoff, which is costlier than a one-level overpay.

## Contributing

Issues and friction reports go under `.tools/<tool-name>/` in your project. For changes to the skill or agents themselves, open an ADR in `.adrs/` with `Scope: strategic` explaining what you want to change and why.
