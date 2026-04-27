---
description: Multi-agent agile workflow for Go projects, v2. Materializes intent in code (// AC: + // SCENARIO: markers) instead of prose intermediaries. Eight agents (PM, architect, sprint-planner, red, green, e2e-tester, reviewer, bug-detective). Two skills (agile-project workflow + task-complexity-routing). Bash scripts (check.sh + pre-commit hook + CI recipe).
tags: [claude-code, agent-team, go, tdd, red-green, sprint-planning, agile, scaffolding, decisions, adr, sub-agents, workflow, v2]
---

# agile-team-v2

Multi-agent agile workflow for Go projects, evolved from `agile-team/` to fix a class of drift problems: **the intent of every feature now lives in the code and the tests, not in prose intermediaries.**

## What changed vs v1

In v1, the intent was scattered across `FEATURE.md`, per-feature `ARCHITECTURE.md`, `TASKS.md`, and three task files (`TASK.md` shared + `TASK-red.md` private + `TASK-green.md` private). Each layer was a potential drift channel — the user-journey narrative could diverge silently from the test assertions, the scaffolded code could drift from the per-feature architecture doc, and the planner had to re-write in prose what the code and tests should say.

v2 collapses the artifacts and inlines the intent:

- **Acceptance criteria live as `// AC: <description>` comments above scaffolded function bodies.** The architect inlines them during scaffolding.
- **User-journey scenarios live as `// SCENARIO: <narrative>` comments above business test skeletons.** The PM inlines them in passe 2.
- **Sprint tasks are listed by code marker** — `TODO(impl-<feat>, ac-NNN)` and `TODO(impl-<feat>, scenario-NNN)` — not by separate prose files.
- **A new `.decisions/` log** (with two-zone frontmatter and `Authored-By:` commit trailer audit) captures both strategic decisions written by the architect and tactical decisions written by green during implementation under R2 strict rules. The architect statues every tactical decision at the start of the next sprint via a Wave 1 task.
- **A new `mechanical: true|false` flag** in FEATURE.md frontmatter (R1) decides whether the PM's passe 2 runs. Wiring/plumbing-only features skip the SCENARIO step entirely.
- **A `check.sh` script** (livré, exécutable) gates the markers, the decision-log format, the override format, the trailer cross-check, and the INDEX.md coherence at both pre-commit and CI levels.

## Repository layout

```
agile-team-v2/
├── README.md                            (this file)
├── agents/
│   ├── product-manager.md               (sonnet — passes 1+2)
│   ├── architect.md                     (opus   — absorbs ex-scaffolder)
│   ├── sprint-planner.md                (opus   — markers, disputes, retro)
│   ├── red.md                           (sonnet — single tier; planner overrides model on demand)
│   ├── green.md                         (sonnet — single tier; planner overrides model on demand)
│   ├── e2e-tester.md                    (sonnet — validates intent, post red/green)
│   ├── reviewer.md                      (sonnet — 3 passes: DoD/Scenarios/Security)
│   └── bug-detective.md                 (sonnet — on-demand investigation)
└── skills/
    ├── agile-project/
    │   ├── SKILL.md                     (the workflow, R1–R6, code markers, all artifact rules)
    │   └── scripts/
    │       ├── check.sh                 (the gate engine; --mode pre-commit | --mode ci)
    │       ├── pre-commit-hook.sh       (wrapper, symlink-able into .git/hooks/pre-commit)
    │       └── ci-recipe.yml            (GitHub Actions template invoking check.sh --mode ci)
    └── task-complexity-routing/
        └── SKILL.md                     (mechanical/standard/architectural routing; pipeline shape only)
```

## Roles at a glance

| Role             | Owns                                                                                              | Model  |
|------------------|---------------------------------------------------------------------------------------------------|--------|
| product-manager  | FEATURE.md narrative; `// SCENARIO:` markers in `pm_test_territories` (passe 2, skipped if mechanical:true); `.features/INDEX.md` (todo/ready transitions). | sonnet |
| architect        | `.architecture/` (VISION + ARCHITECTURE + CONVENTIONS + INTEGRATIONS); `.adrs/` strategic; `.decisions/` (writes strategic, statues tactical); scaffolded production signatures with `// AC:` + `panic`; `mechanical:` flag in FEATURE.md. | opus   |
| sprint-planner   | SPRINT.md (tasks listed by code marker); dispute decisions (7 types A–G); RETRO.md `## Metrics` + YAML (incl. `decisions_to_statue:`); sub-sprint creation. | opus   |
| red              | `*_test.go`, `testdata/`, `testutil/`, `mocks/` (failing assertions; replaces PM's `t.Skip` in business tests). | sonnet |
| green            | Non-test `.go` files (function bodies + private helpers); tactical DECISIONS in `.decisions/` under R2; `RETRO.md helpers_added:` (append-only). | sonnet |
| e2e-tester       | E2E scenarios in `pm_test_territories` (real entry points + testcontainers).                                                                              | sonnet |
| reviewer         | REVIEW.md `## Findings` (3 passes); `.features/INDEX.md` `done`/`blocked`; `.sprints/INDEX.md` `done`. | sonnet |
| bug-detective    | `.bugs/<bug-id>.md` (post-mortem; classification implementation/spec/architectural; never proposes the fix).                                                | sonnet |

## The lifecycle of a feature

```
                              ┌──────────────────────────────────────┐
                              │ Phase 0 — One-shot project setup     │
                              │ architect creates .architecture/*    │
                              │ + .decisions/INDEX.md                │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 1 — PM passe 1                 │
                              │ FEATURE.md (Why, Context, User       │
                              │ journey, Out of scope, Open Qs)      │
                              │ INDEX.md status=todo                 │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 2 — Architect (ex-scaffolder)  │
                              │ Scaffolds .go signatures + // AC:    │
                              │ + TODO(impl-<feat>, ac-NNN) + panic  │
                              │ Empty test skeletons in              │
                              │ pm_test_territories                  │
                              │ DECISIONS new if needed              │
                              │ Sets mechanical:true|false           │
                              │ INDEX.md status=scaffolded           │
                              │ (or =ready if mechanical:true)       │
                              └──────────────────────────────────────┘
                                              │
                                  ┌───────────┴──────────┐
                                  │ mechanical: true ?   │
                                  └───┬──────────────┬───┘
                              false   │              │   true
                                      ▼              │
                ┌──────────────────────────────┐    │
                │ Phase 3 — PM passe 2         │    │
                │ Inline // SCENARIO: + t.Skip │    │
                │ in pm_test_territories       │    │
                │ INDEX.md status=ready        │    │
                └──────────────────────────────┘    │
                                      │              │
                                      └──────┬───────┘
                                             ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 4 — Sprint planning            │
                              │ SPRINT.md lists tasks BY CODE MARKER │
                              │ (TODO(impl-<feat>, ac-NNN) etc.)     │
                              │ Wave 1: statue prior tactical        │
                              │   DECISIONS (architect)              │
                              │ INDEX.md status=in-progress          │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 5 — TDD execution              │
                              │ red writes assertions                │
                              │   → commit Task: <feat>-T<NNN>-red   │
                              │ green replaces panic with impl       │
                              │   → commit Task: <feat>-T<NNN>-green │
                              │ disputes via .disputes/, planner     │
                              │   arbitrates citing public artifacts │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 6 — e2e-tester                 │
                              │ Translates t.Skip into real e2e      │
                              │ (real entry points + testcontainers) │
                              │ Skipped if mechanical:true           │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 7 — Reviewer (3 passes)        │
                              │ Pass 1 DoD: invoke scripts/check.sh  │
                              │ Pass 2 Scenarios: User journey vs    │
                              │   // SCENARIO: alignment             │
                              │ Pass 3 Security: IDOR/authz/SSRF/    │
                              │   injection/secrets/validation       │
                              │ REVIEW.md ## Findings (reviewer)     │
                              │ ## Human override (human, optional)  │
                              │ INDEX.md status=done                 │
                              └──────────────────────────────────────┘
                                              │
                                              ▼
                              ┌──────────────────────────────────────┐
                              │ Phase 8 — Retro                      │
                              │ sprint-planner ## Metrics + YAML     │
                              │   (incl. decisions_to_statue:)       │
                              │ human writes ## Reflection           │
                              │ Sub-sprint SPRINT_00X-A if helpers   │
                              │ Wave 1 task in SPRINT_00X+1 for      │
                              │   architect to statue DECISIONS      │
                              └──────────────────────────────────────┘
```

## Code markers

Defined in `.architecture/CONVENTIONS.md` and enforced by `check.sh`:

```go
// AC: <criterion>
// TODO(impl-<feature-slug>, ac-<NNN>)
panic("not implemented")
```

```go
// SCENARIO: <narrative>
// TODO(impl-<feature-slug>, scenario-<NNN>)
t.Skip("not implemented")
```

`<NNN>` is local to the feature, zero-padded to three digits, starting at `001`. Stable across the feature's lifetime.

`pm_test_territories` (glob list in `.architecture/CONVENTIONS.md`) scopes where `// SCENARIO:` markers may live:

```yaml
pm_test_territories:
  - tests/e2e-api/
  - tests/contract/
  - "**/usecase/*_test.go"
  - "**/usecases/*_test.go"
```

## Hard rules

The `agile-project` skill defines six transverse rules that constrain the workflow:

- **R1** — `mechanical:` flag is the architect's exclusive write zone. PM never touches it. Rationale mandatory if `true`.
- **R2** — Green may write tactical DECISIONS only under four conditions (scope=tactical, revisit=true, necessary, referenced). Architect statues at start of next sprint.
- **R3** — REVIEW.md `## Human override` is human-only with strict 5-field format. Security findings cannot be overridden without a `Decision reference: DECISION-NNN`.
- **R4** — Marker linter and `--no-verify` audit. Pre-commit (bypassable) + CI (no bypass). Reviewer's pass 1 invokes the script.
- **R5** — `.features/INDEX.md` lifecycle. Status posted by the agent that finishes the step, never a supervisor.
- **R6** — `.decisions/` zone review + `Authored-By:` trailer. Three-level defence (pre-commit format, CI cross-check git blame ↔ trailer, reviewer pass DoD sanity check).

The full rule text is in `skills/agile-project/SKILL.md`.

## Scripts

### Installation (in your project repo)

1. Copy `skills/agile-project/scripts/check.sh` to your repo (e.g., `scripts/check.sh`). Or vendor the whole `agile-team-v2/` directory and reference it.
2. Symlink the pre-commit hook:

   ```bash
   ln -sf ../../scripts/agile-team-v2/skills/agile-project/scripts/pre-commit-hook.sh \
          .git/hooks/pre-commit
   ```

3. Add the GitHub Actions recipe:

   ```bash
   cp skills/agile-project/scripts/ci-recipe.yml .github/workflows/agile-gate.yml
   ```

4. Adapt `ci-recipe.yml`: matrix Go versions, golangci-lint pinning, `CHECK_SH_PATH` env var if check.sh is not at `scripts/check.sh`.

### `check.sh --mode pre-commit`

Fast checks. Bypassable with `git commit --no-verify` (technically) but the bypass is detected and blocked at CI. Runs:

- Marker linting (`// SCENARIO:` outside `pm_test_territories`, malformed `TODO(impl-...)`).
- `.decisions/` frontmatter validation (zone author, zone review, R2 rules for green).
- REVIEW.md `## Human override` 5-field format.
- Security override `Decision reference` requirement.

### `check.sh --mode ci`

Full audit. No bypass. All pre-commit checks plus:

- `golangci-lint`, `go test`, `go build`, `go vet`.
- Unresolved `TODO(impl-<slug>, ...)` on a feature `done` in INDEX.md.
- Tactical DECISIONS not statued after one sprint window (R2).
- INDEX.md ↔ reality coherence (`done` with leftover TODOs, `ready` without scaffolding, `in-progress` without active SPRINT.md).
- `--no-verify` commit detection on the sprint window (R4).
- `Authored-By:` trailer cross-check on `.decisions/` and `mechanical:` modifications (R6).
- `mechanical:` flag presence on every feature at status `scaffolded` or beyond.

## Derogations vs `agile-team-refonte-bloc1.md`

The refonte document is the canonical reference for v2. The user opted into four explicit derogations:

1. **Tier fusion (anticipates bloc 3 of the refonte doc).** The refonte doc lists `red-haiku` / `red-sonnet` / `red-opus` and `green-haiku` / `green-sonnet` / `green-opus` as "unchanged in bloc 1" (l. 145, 161, 626). v2 collapses these to a single `red.md` (sonnet) and a single `green.md` (sonnet) — a behaviour the doc puts under bloc 3. The sprint-planner overrides the model at spawn time when needed (`Agent({subagent_type: "red", model: "opus"})`). Consequence: the `task-complexity-routing` skill no longer routes red/green models — only pipeline shape.

2. **`task-complexity-routing` simplified.** Following derogation 1, the section "Red and green models are picked independently" is removed from the skill. Pipeline shape (mechanical / standard / architectural) is the only routing dimension.

3. **From scratch, not copy-then-patch.** v2 is rewritten end-to-end rather than incrementally patched from v1. Yields better internal coherence at the cost of more upfront work.

4. **Scripts livrés exécutables.** `check.sh` and `pre-commit-hook.sh` are bash, executable, and shipped. The refonte doc only specifies what the scripts must check; v2 implements them as a starting point users can adapt.

## Getting started

### First sprint, from scratch

1. Initialize the directory layout:

   ```
   .architecture/
   .decisions/INDEX.md
   .features/INDEX.md
   .sprints/INDEX.md
   ```

   The `architect` agent creates `.architecture/{VISION,ARCHITECTURE,CONVENTIONS,INTEGRATIONS}.md` on its first invocation. `pm_test_territories` declared in `CONVENTIONS.md`.

2. Install the pre-commit hook and the CI recipe (see Scripts section above).

3. Draft the first feature with the PM (passe 1).

4. Invoke the architect to enrich DoR, scaffold, set `mechanical:`.

5. If `mechanical: false`: invoke the PM passe 2 to inline `// SCENARIO:` in test skeletons.

6. Invoke the sprint-planner to produce SPRINT.md.

7. Execute waves: red → green → (e2e-tester) → reviewer.

8. At sprint end: sprint-planner generates retro, reviewer signs off sprint REVIEW.md.

9. At start of next sprint: sprint-planner places the architect's DECISION-statuing task in Wave 1.

### Migrating from v1

If you ran an `agile-team/` project and want to migrate:

- The v1 `OVERVIEW.md` content splits into `VISION.md` (the why) and `ARCHITECTURE.md` (the how).
- The v1 per-feature `ARCHITECTURE.md` is folded into either `.architecture/ARCHITECTURE.md` (cross-cutting parts) or into the inlined `// AC:` markers (feature-specific contracts).
- The v1 `TASKS.md`, `TASK.md`, `TASK-red.md`, `TASK-green.md`, `SCAFFOLD.md` are **deleted**. The agents now read inline markers + FEATURE.md.
- The v1 ADR-tactical work moves into `.decisions/`. Strategic ADRs stay in `.adrs/`.
- The v1 six tier-specific agents (`red-haiku/sonnet/opus`, `green-haiku/sonnet/opus`) collapse to two (`red`, `green`).

A migration script is not provided — the change is structural enough that a manual review per feature is recommended.

## Known limitations

- **Spec isolation by discipline, not by file.** Without `TASK-red.md` / `TASK-green.md`, isolation depends on red/green not reading each other's in-flight work. The `Authored-By:` trailer audit catches some violations post-hoc, but not all. Working as agent teams (where each teammate has its own context) is the strongest enforcement.
- **`check.sh` is bash.** Portable on Linux and macOS; on Windows, expect to run it under WSL or Git Bash. The `awk` and `grep` invocations assume GNU semantics in places.
- **Markers in code couple intent to file paths.** Renaming a function or moving a package re-locates the markers. Plan migrations to keep `// AC:` and `TODO(impl-...)` consistent with their FEATURE.md.
- **CI relies on git history.** A squash-merge to `main` collapses commit trailers. The CI workflow above runs on PRs (full history) before squash; on `main` itself the audit is partial. Document your merge strategy in `.architecture/CONVENTIONS.md` `## Branching and push timing`.

## Contributing

Skill issues, agent corrections, script bugs → file under `.tools/agile-team-v2/` in your project's tooling-feedback location, or open an issue on the `claude-skills` repo.
