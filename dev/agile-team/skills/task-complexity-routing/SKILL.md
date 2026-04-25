---
name: task-complexity-routing
description: "Use this skill when classifying a feature or task complexity (mechanical, standard, architectural), when deciding which pipeline level applies to a given work item, when escalating a task to a higher complexity level during execution, or when reviewing classification accuracy during retro. Triggers on FEATURE.md DoR review, sprint planning, task escalation via dispute or blocker, and RETRO.md classification accuracy sections. Consult this skill before setting a complexity field, before deciding whether to skip PM/Architect/scaffolder phases, before downgrading a pipeline, and when analyzing past sprints for routing calibration. Do NOT load this skill for routine feature implementation — it is only needed at classification and routing decision points."
---

# Task complexity routing

Classification heuristics and routing rules for the three complexity levels defined in the agile-project workflow.

The `complexity` field itself, its presence in FEATURE.md, and the DoR gate are defined in the `agile-project` skill. This skill contains the decision-making heuristics for agents who classify or re-classify work.

---

## The three levels

### mechanical

Transformation whose correct result is unique or quasi-unique. Nobody needs to give an opinion on the outcome — there is an identifiable right answer.

Characteristics:
- No design decision involved
- No new contract introduced
- No invariant modified
- Result can be verified objectively by tests or type checks
- A single agent can produce the correct output in one pass

Examples:
- Rename a local variable
- Extract a private function from an existing function
- Add a missing test on existing code (retroactive coverage)
- Fix a typo in a comment, error message, or log line
- Apply a linter suggestion
- Regenerate a mock after an interface change already decided
- Update a dependency without API impact
- Run goimports, gofmt, standard formatters

Pipeline: **single-agent task**. One Opus or Sonnet with go-surgeon access and direct prompt. No PM, no Architect, no Scaffolder, no red/green split.

### standard

Clear implementation of a decision already made. Several ways to code it exist, but no major architectural decision is needed. The DoD can be written precisely upfront.

Characteristics:
- No new public contract (type, interface, endpoint, event)
- Follows an established pattern in the codebase
- Impact scope fits within one bounded context
- Applicable ADRs already exist and cover the case
- Testing strategy is known from similar features

Examples:
- Add a CRUD endpoint to an existing service following the pattern
- Add a field to a persisted struct with its migration
- Implement a documented business use case
- Add a middleware that follows an existing pattern
- Create a new repository following existing conventions
- Implement validation according to specified rules

Pipeline: **reduced pipeline**. Skip PM and Architect phases (spec is already clear, ADRs already apply). Direct Planner → Scaffolder → Red/Green → Reviewer. Full triptyque TASK.md + TASK-red.md + TASK-green.md applies.

### architectural

Introduction of a new contract, decision affecting multiple features, modification of an invariant, or choice among several defensible approaches.

Characteristics:
- Introduces a new exported type, interface, or endpoint
- Modifies a signature used by multiple callers
- Changes an external contract (HTTP, gRPC, event, persistence schema)
- Introduces a new structural dependency
- Requires data migration
- Multiple defensible approaches with no objective criterion for choice
- Affects invariants assumed elsewhere in the code

Examples:
- New bounded context or new service
- New publicly shared interface
- Signature change used by multiple callers
- External contract modification (HTTP, gRPC, event)
- New structural dependency introduction
- Cross-cutting refactor (auth, logging, errors)
- Pattern choice that will be replicated elsewhere

Pipeline: **full pipeline**. PM → Architect → Planner → Scaffolder → Red/Green → E2E → Reviewer with mandatory strategic ADR.

---

## Escalation signals

When in doubt between two levels, prefer the higher one. The cost of over-pipelining a task is coordination overhead; the cost of under-pipelining is missed design decisions that surface as refactors or bugs later.

### Signals that push `mechanical` → `standard`

- More than one file touched
- Touches code covered by integration tests
- Modifies a signature used elsewhere (even within the same package)
- Requires adding a new test file (not just adding cases to existing one)
- The fix for a symptom might have side effects elsewhere

### Signals that push `standard` → `architectural`

- Introduces a new exported type, function, or interface
- Modifies an invariant assumed by other code
- Requires data migration
- Impacts an external contract
- Multiple defensible approaches without objective criterion
- Touches a cross-cutting concern (auth, errors, logging, observability)
- Decision will be referenced by future features

### Explicit escalation during execution

A task can **upgrade** its complexity level during execution but **never downgrade**. This asymmetry protects against pressure to rush.

- A `mechanical` agent who discovers a design decision must stop, escalate to the planner who re-classifies the task as `standard` or `architectural` and restarts with the appropriate pipeline.
- A `standard` red or green agent who encounters an architectural question opens a dispute or blocker that escalates to the planner.
- The planner invokes architect re-entry for any escalation to `architectural`.

If the planner initially over-classified a task (e.g., architectural that turned out trivial), the correction is documented in retro for calibration — not applied retroactively by downgrading the task in flight.

---

## Integration with the pipeline

### At feature creation (PM)

When creating FEATURE.md, the PM proposes an initial complexity based on their understanding. The Architect confirms or amends during DoR enrichment. The complexity field is part of the DoR gate.

PM heuristic: classify on functional complexity (how many user-visible changes, how many flows affected). If unsure, default to `standard`.

### At DoR enrichment (Architect)

The Architect validates the complexity from technical angle. Common adjustments:

- PM proposed `standard`, Architect upgrades to `architectural` because the feature introduces a new interface → document the rationale in FEATURE.md `## Complexity rationale`
- PM proposed `architectural` but Architect sees the work follows an established pattern and existing ADRs cover it → downgrade to `standard` with rationale

### At sprint planning (Planner)

The Planner reads the complexity and decides pipeline routing:

- `mechanical` → creates a single-file TASK.md, assigns one agent, no red/green split
- `standard` → creates the triptyque TASK.md + TASK-red.md + TASK-green.md, assigns red/green pair, no PM/Architect re-entry
- `architectural` → full pipeline, all phases

The SPRINT.md `## Routing decisions` section documents what was decided per feature.

### Red and green models are picked independently

Feature-level complexity (`mechanical` / `standard` / `architectural`) routes the **pipeline shape** (which phases run, which files are produced). It does **not** fix the model tier of the red/green teammates.

For every red/green task triple the planner makes **two separate model decisions**:

- **Red tier** — picked from `{red-haiku, red-sonnet, red-opus}` based on test-design complexity (number of cases, concurrency assertions, mocking depth, contract-test setup, invariants to exercise).
- **Green tier** — picked from `{green-haiku, green-sonnet, green-opus}` based on implementation complexity (algorithmic difficulty, cross-cutting effects, concurrency, ADR-level choices).

Any combination is legal. Common asymmetric pairings:

- `red-opus` + `green-haiku` — hard-to-design test suite (e.g., state machine invariants) against a mechanical implementation that just wires pieces together.
- `red-haiku` + `green-opus` — simple assertions (input → output) against an implementation that hides real concurrency or algorithmic complexity behind the interface.
- `red-sonnet` + `green-opus` — standard use-case tests against a cross-cutting implementation (middleware, auth wiring) that has ADR-level decisions.

The planner must **never** promote or demote red and green together just because they are paired. If in doubt on either side individually, promote that side to opus — under-assignment on one side triggers mid-task handoff regardless of what the other side is doing.

At retro, classification accuracy is tracked **per side** (red and green assignments are reviewed separately) — a task can be a hit on red and a miss on green, or vice versa. The structured retro fields capture this in `complexity_routing.upgrades` and `observed_downgrades` (see schema below).

### During execution (agents)

Any agent can trigger an escalation by opening a dispute (type G — complexity upgrade) with the escalation rationale. The planner is the sole authority on re-classification. Agents never self-upgrade or self-downgrade. The exact dispute protocol and the G-finish-then-escalate / G-immediate-rerun decisions are defined in the `agile-project` skill.

### At retro (Planner)

Routing accuracy and calibration data live in the **`RETRO.md` YAML frontmatter** under the `complexity_routing:` block — this is the single source of truth for classification feedback. The schema is defined in the `agile-project` skill (see *Retrospective* template). It contains:

- `classification_accuracy: { correct, total }` — the hit/miss counts for the sprint.
- `upgrades:` — corrections actually applied (in flight via dispute G or as scheduled follow-ups).
- `observed_downgrades:` — over-classifications noted but never applied (the no-downgrade-in-flight rule).
- `heuristic_adjustments:` — short strings describing the pattern-level rules to adopt next sprint (e.g., *"resilience patterns → default to architectural"*).

Narrative analysis of these numbers (why the misclassification happened, whether it is a recurring pattern) goes in the prose section `## Complexity calibration` of the same RETRO. Do not duplicate the structured data into the prose — the YAML is authoritative.

This is the feedback loop that calibrates the classification heuristics over time. New heuristics added here become the input to next sprint's DoR enrichment by the Architect.

---

## Mono-agent task structure

For `mechanical` tasks, the triptyque is replaced by a single file:

```markdown
# TASK_<id>.md

## Complexity
mechanical

## Goal
[Direct description of the transformation]

## Success criteria
- [ ] Code compiles
- [ ] Existing tests still pass
- [ ] Specific criterion 1
- [ ] Specific criterion 2

## Assigned agent
<opus | sonnet | haiku>

## Constraints
- Must use go-surgeon for all .go file edits
- [Other specific constraints if applicable]

## Applicable ADRs
- [list from FEATURE.md, even if few]
```

The commit uses the same trailers as any other task:

```
<short description>

Feature: <slug>
Task: <TASK_ID>
```

The absence of `-red` or `-green` suffix in the Task trailer indicates a mono-agent task.

---

## Anti-patterns

**Never classify by file count alone.** A one-file change can be architectural (new public interface in that file). A ten-file change can be mechanical (renaming one variable across files).

**Never classify by estimated effort alone.** A five-minute change can be architectural if it changes an invariant. A three-hour change can be mechanical if it's pure volume without decisions.

**Never skip classification to save time.** An unclassified feature fails DoR and cannot enter a sprint. The five minutes spent classifying save hours of wrong pipeline application.

**Never downgrade in flight.** If a task was over-classified, document it in retro and keep it on its assigned pipeline. Downgrading mid-execution creates inconsistent traces.

**Never upgrade silently.** An upgrade from `mechanical` to `standard` or `architectural` must go through the planner with documented rationale, not through the executing agent deciding on its own.
