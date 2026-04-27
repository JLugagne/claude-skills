---
name: task-complexity-routing
description: "Use this skill when classifying a feature's complexity (mechanical, standard, architectural), when deciding which pipeline shape applies to a given feature, when escalating a task to a higher complexity level during execution, or when reviewing classification accuracy at retro. Triggers on FEATURE.md DoR review, sprint planning, task escalation via dispute or blocker, and RETRO.md classification accuracy sections. The complexity classification is **distinct** from the `mechanical:` flag in FEATURE.md frontmatter — they answer different questions and live under different rules. Complexity drives **pipeline shape** (which phases run); the mechanical flag drives **whether the PM does passe 2** (skipped if true). Both can be set independently. In v2 the agent tier system was simplified — there is one `red` agent and one `green` agent, no per-tier variants — so this skill no longer routes red/green models, only pipeline shape. Consult before setting a complexity field, before deciding whether to skip PM/architect/scaffolder phases, before downgrading a pipeline (forbidden), and when analyzing past sprints for routing calibration. Do NOT load this skill for routine implementation work — it is only needed at classification and routing decision points."
---

# Task complexity routing

Classification heuristics and routing rules for the three complexity levels defined in the agile-project workflow.

The `complexity` field itself, its presence in `FEATURE.md`, and the DoR gate are defined in the `agile-project` skill. This skill contains the decision-making heuristics for agents who classify or re-classify work.

**Distinct from `mechanical:`.** The `mechanical: true|false` flag in FEATURE.md frontmatter (R1 in the agile-project skill) is set by the architect at end of scaffolding and decides whether the PM does passe 2 (skipped if `true`). The `complexity` classification (this skill) is set at DoR enrichment by the architect with PM input and decides which pipeline phases run. The two flags can be combined freely:

- `complexity: mechanical` + `mechanical: true` — the typical mono-agent task (rename, dep bump, lint, refactor without behaviour change). No PM passe 2.
- `complexity: standard` + `mechanical: true` — wiring that touches enough files to warrant the standard pipeline (red/green discipline) but has no business behaviour. No PM passe 2.
- `complexity: standard` + `mechanical: false` — most features. PM passe 2 runs.
- `complexity: architectural` + `mechanical: false` — full pipeline including PM passe 2 and a strategic ADR.
- `complexity: architectural` + `mechanical: true` — rare. Architectural decision (new contract) but no business behaviour beyond plumbing. PM passe 2 skipped, but the strategic ADR is still mandatory.

---

## The three levels

### mechanical

Transformation whose correct result is unique or quasi-unique. Nobody needs to give an opinion on the outcome — there is an identifiable right answer.

Characteristics:
- No design decision involved.
- No new contract introduced.
- No invariant modified.
- Result can be verified objectively by tests or type checks.
- A single agent can produce the correct output in one pass.

Examples:
- Rename a local variable.
- Extract a private function from an existing function.
- Add a missing test on existing code (retroactive coverage).
- Fix a typo in a comment, error message, or log line.
- Apply a linter suggestion.
- Regenerate a mock after an interface change already decided.
- Update a dependency without API impact.
- Run goimports, gofmt, standard formatters.

Pipeline: **single-agent task**. One sonnet (or opus on demand) with `go-surgeon` access and a direct prompt. No PM, no architect re-entry, no separate red/green split. The architect's scaffolding step still runs (in fact the change *is* the scaffolding), and the reviewer still runs at the end — that's the minimal skeleton. The mono-agent task is documented in `SPRINT.md` like any other but with a single line under the marker (no red/green pair).

### standard

Clear implementation of a decision already made. Several ways to code it exist, but no major architectural decision is needed. The behaviour can be expressed precisely upfront via `// AC:` markers.

Characteristics:
- No new public contract (type, interface, endpoint, event).
- Follows an established pattern in the codebase.
- Impact scope fits within one bounded context.
- Applicable DECISIONS / ADRs already exist and cover the case.
- Testing strategy is known from similar features.

Examples:
- Add a CRUD endpoint to an existing service following the pattern.
- Add a field to a persisted struct with its migration.
- Implement a documented business use case.
- Add a middleware that follows an existing pattern.
- Create a new repository following existing conventions.
- Implement validation according to specified rules.

Pipeline: **reduced pipeline**. Architect scaffolds → red writes failing assertions → green implements → reviewer signs off. PM passe 1 still produces FEATURE.md narrative. PM passe 2 runs only if `mechanical: false`. No new strategic ADR is mandatory (existing ones cover).

### architectural

Introduction of a new contract, decision affecting multiple features, modification of an invariant, or choice among several defensible approaches.

Characteristics:
- Introduces a new exported type, interface, or endpoint.
- Modifies a signature used by multiple callers.
- Changes an external contract (HTTP, gRPC, event, persistence schema).
- Introduces a new structural dependency.
- Requires data migration.
- Multiple defensible approaches with no objective criterion for choice.
- Affects invariants assumed elsewhere in the code.

Examples:
- New bounded context or new service.
- New publicly shared interface.
- Signature change used by multiple callers.
- External contract modification (HTTP, gRPC, event).
- New structural dependency introduction.
- Cross-cutting refactor (auth, logging, errors).
- Pattern choice that will be replicated elsewhere.

Pipeline: **full pipeline**. PM passe 1 → architect (DoR enrichment + strategic ADR if needed + scaffolding) → PM passe 2 (unless `mechanical: true`) → red → green → e2e-tester (unless `mechanical: true`) → reviewer. Strategic ADR is **mandatory** before scaffolding starts.

---

## Escalation signals

When in doubt between two levels, prefer the higher one. The cost of over-pipelining a task is coordination overhead; the cost of under-pipelining is missed design decisions that surface as refactors or bugs later.

### Signals that push `mechanical` → `standard`

- More than one file touched.
- Touches code covered by integration tests.
- Modifies a signature used elsewhere (even within the same package).
- Requires adding a new test file (not just adding cases to an existing one).
- The fix for a symptom might have side effects elsewhere.

### Signals that push `standard` → `architectural`

- Introduces a new exported type, function, or interface.
- Modifies an invariant assumed by other code.
- Requires data migration.
- Impacts an external contract.
- Multiple defensible approaches without objective criterion.
- Touches a cross-cutting concern (auth, errors, logging, observability).
- Decision will be referenced by future features.

### Explicit escalation during execution

A task can **upgrade** its complexity level during execution but **never downgrade**. This asymmetry protects against pressure to rush.

- A `mechanical` mono-agent who discovers a design decision must stop, escalate to the sprint-planner who re-classifies the task as `standard` or `architectural` and restarts with the appropriate pipeline.
- A `standard` red or green who encounters an architectural question opens a dispute that escalates to the sprint-planner.
- The sprint-planner invokes architect re-entry for any escalation to `architectural`.

If the sprint-planner initially over-classified a task (e.g., architectural that turned out trivial), the correction is documented in retro for calibration — not applied retroactively by downgrading the task in flight.

The exact dispute protocol and the G-finish-then-escalate / G-immediate-rerun decisions are defined in the `agile-project` skill (Disputes section, decision type G). Mid-task agent handoff is forbidden — either the current agent finishes the task with the simplest correct implementation (G-finish-then-escalate, default) or the in-progress work is reverted and re-routed (G-immediate-rerun).

---

## Integration with the pipeline

### At feature creation (PM passe 1)

The PM proposes an initial complexity based on functional understanding. The architect confirms or amends during DoR enrichment.

PM heuristic: classify on functional complexity (how many user-visible flows change, how many personas affected). If unsure, default to `standard`.

### At DoR enrichment (architect)

The architect validates the complexity from a technical angle. Common adjustments:

- PM proposed `standard`, architect upgrades to `architectural` because the feature introduces a new interface → document the rationale in FEATURE.md `## Complexity rationale`.
- PM proposed `architectural`, architect sees the work follows an established pattern and existing DECISIONS / ADRs cover it → downgrade to `standard` with rationale.

The architect also sets the **distinct** `mechanical:` flag at end of scaffolding (R1). The two flags can disagree (see the introduction).

### At sprint planning (sprint-planner)

The sprint-planner reads the complexity and decides pipeline routing:

- `mechanical` → mono-agent task (single line in SPRINT.md execution plan, no red/green pair).
- `standard` → red/green pair on each `// AC:` marker. PM passe 2 runs unless `mechanical: true`.
- `architectural` → full pipeline including PM passe 2 (unless `mechanical: true`) and e2e-tester.

The SPRINT.md `## Routing decisions` section documents what was decided per feature.

### Tier fusion (anticipates bloc 3 of the refonte doc)

In v2, the v1 system of red-haiku / red-sonnet / red-opus and green-haiku / green-sonnet / green-opus is **collapsed** to a single `red` agent and a single `green` agent (sonnet by default). Pipeline shape is decided by complexity (this skill); model tier is decided by the sprint-planner at spawn time via `Agent({subagent_type: "red", model: "opus"})` or `Agent({subagent_type: "green", model: "haiku"})` if the planner judges the assigned model is wrong.

This skill therefore **does not** route red/green models — only pipeline shape. Past v1 logic about "red and green models picked independently" is no longer applicable; that complexity now lives in the sprint-planner's runtime decisions.

### During execution (agents)

Any agent can trigger an escalation by opening a dispute (type G — complexity upgrade) with the rationale. The sprint-planner is the sole authority on re-classification. Agents never self-upgrade or self-downgrade.

### At retro (sprint-planner)

Routing accuracy and calibration data live in the `RETRO.md` YAML frontmatter under the `complexity_routing:` block:

- `classification_accuracy: { correct, total }` — hit/miss counts for the sprint.
- `upgrades:` — corrections actually applied (in flight via dispute G or as scheduled follow-ups).
- `observed_downgrades:` — over-classifications noted but never applied (the no-downgrade-in-flight rule).
- `heuristic_adjustments:` — short strings describing the pattern-level rules to adopt next sprint (e.g., `"resilience patterns → default to architectural"`).

Narrative analysis goes in the prose section `## Reflection` (human) or in the sprint-planner's `## Metrics` summary. The YAML is authoritative; do not duplicate the structured data into the prose.

This is the feedback loop that calibrates the heuristics over time. New entries in `heuristic_adjustments` become input to next sprint's DoR enrichment.

---

## Mono-agent task structure (for `complexity: mechanical`)

The architect scaffolds and implements in a single pass (or assigns a single agent to do both — typically the architect or green-as-mono via a model override). There is no separate red/green pair; instead the SPRINT.md execution plan has one line:

```markdown
- [ ] mono — TODO(impl-rename-userid, ac-001) (model: sonnet, agent: green)
```

The commit uses the same trailers as any other task:

```
mono: rename UserID across handlers

Feature: rename-userid
Task: rename-userid-T001
```

The absence of `-red` or `-green` suffix in `Task:` is the convention indicating a mono-agent task. The reviewer pass DoD verifies the mono-task has at least the necessary tests (existing tests still pass, since the work is supposed to be behaviour-preserving by definition of `mechanical`).

---

## Anti-patterns

**Never classify by file count alone.** A one-file change can be architectural (new public interface in that file). A ten-file change can be mechanical (renaming one variable across files).

**Never classify by estimated effort alone.** A five-minute change can be architectural if it changes an invariant. A three-hour change can be mechanical if it's pure volume without decisions.

**Never skip classification to save time.** An unclassified feature fails DoR and cannot enter a sprint. The five minutes spent classifying save hours of wrong pipeline application.

**Never downgrade in flight.** If a task was over-classified, document it in retro and keep it on its assigned pipeline. Downgrading mid-execution creates inconsistent traces.

**Never upgrade silently.** An upgrade from `mechanical` to `standard` or `architectural` must go through the sprint-planner via dispute G with documented rationale, not through the executing agent deciding on its own.

**Never confuse `complexity` with `mechanical:`.** They are distinct flags answering distinct questions. A `complexity: standard` feature can be `mechanical: true` (wiring that warrants the standard pipeline but has no business behaviour). A `complexity: architectural` feature is almost always `mechanical: false`, but exceptions exist (introducing a new internal contract that has no user-visible behaviour).
