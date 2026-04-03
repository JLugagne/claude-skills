# Product Manager Patterns

Reference templates for go-product-manager. Read specific sections as needed.

## PRODUCT.md Template

Use this template when writing `.plan/PRODUCT.md` after decomposing the product spec.

```markdown
# Product: [Name]

## Status: [INTERROGATION | GREEN — ready for execution]

## Source
[Path to the product spec document, or "User conversation"]
<!-- Link to the original document so future agents can reference it -->

## Architectural Constraints
<!-- Extract from the spec — these go into the project CLAUDE.md -->
<!-- These are product-wide invariants that apply to EVERY feature -->
- [Constraint 1 — e.g., "tenant_id mandatory in every query"]
- [Constraint 2 — e.g., "push-only, no Git credential storage"]
- [Constraint 3 — e.g., "zero-downtime migrations only"]

## Infrastructure
<!-- What go-bootstrap needs to set up -->
<!-- List only what the product actually requires, not everything available -->
- Database: [Postgres, Redis, etc.]
- Messaging: [NATS, RabbitMQ, etc.]
- Auth: [Zitadel, JWT, etc.]
- Storage: [S3, etc.]

## Features

<!-- Dependency ordering is critical: features build on each other -->
<!-- Status values: pending, in-progress, done, blocked -->
| # | Feature | Context | Depends On | Status |
|---|---------|---------|------------|--------|
| 1 | [Name] | [bounded context] | — | pending |
| 2 | [Name] | [bounded context] | 1 | pending |
| 3 | [Name] | [bounded context] | 1 | pending |
| 4 | [Name] | [bounded context] | 2, 3 | pending |

## Feature Details

### Feature 1: [Name]
**Context:** [bounded context]
**Summary:** [2-3 sentences — what it does, why it matters]
**Entities:** [key entities involved]
**Endpoints:** [key API endpoints, if any]
**Events:** [events consumed or emitted, if any]
**Decisions:** [key decisions from questionnaire answers — added after Step 7]
**Acceptance:** [high-level definition of done — go-pm will expand this]
<!-- Keep summaries concise — go-pm will interrogate the full detail -->

### Feature 2: [Name]
...

## Coherence Log

| Date | Verdict | Conflicts | Resolution |
|------|---------|-----------|------------|
| YYYY-MM-DD | RED | [conflict summary] | [questionnaire round 2] |
| YYYY-MM-DD | GREEN | none | ready for execution |
```

## Feature Dispatch Prompt

Use this when invoking go-pm for each feature.

```
New feature for the product. Here is the context:

# Feature
[Feature detail section from PRODUCT.md]
<!-- Copy the Feature N section verbatim — go-pm needs the summary,
     entities, endpoints, events, and acceptance criteria as a starting point -->

# Decisions Already Made
[Summarize key questionnaire answers for this feature from PRODUCT.md]
<!-- go-pm should NOT re-interrogate these — they are settled at the product level -->
<!-- Include entity definitions, error behaviors, cross-feature contracts that were decided -->

# Product Context
[Relevant constraints and decisions from CLAUDE.md]
<!-- Include architectural constraints that affect this specific feature -->
<!-- Don't dump the entire CLAUDE.md — only what's relevant -->

# Existing Codebase
The codebase already has: [list bounded contexts and key entities from previous features]
<!-- This prevents go-pm from asking questions the codebase already answers -->
<!-- List concrete paths: internal/identity/, internal/sbom/, etc. -->
<!-- List key entities: Tenant, User, SBOM, Component, etc. -->

Interrogate the spec, write FEATURE.md, plan with go-architect, and execute with go-runner.
```

## Progress Report

Use this format after each feature completes.

```
## Product Progress

Features completed: N/M
Current: Feature X — [name]
Next: Feature Y — [name] (depends on X)

Completed:
✓ Feature 1 — [name]
✓ Feature 2 — [name]

Remaining:
○ Feature X — [name] (in progress)
○ Feature Y — [name]
```

## Feature Questionnaire Template

Use this when writing `.plan/questions/<feature-slug>.md`.

```markdown
# Questions: [Feature Name]

Feature: #N — [Name]
Context: [bounded context]
Round: [1 | 2 | 3...]

Instructions: For each question, mark your choice with [x].
If none fit, write your answer under "Other".
Save when done, re-invoke @go-product-manager.

---

## Q1: [Short title]

**Context:** [what the spec says]
**Gap:** [what's unclear]
**Why it matters:** [what breaks if we guess wrong]

- [ ] **A) [Solution]** — [description + trade-off]
- [ ] **B) [Alternative]** — [description + trade-off]
- [ ] **C) [Third option if applicable]** — [description + trade-off]
- [ ] **Other:**
  [Write your answer here]

---

## Q2: [Short title]
...

---

## Additional context
[Anything not covered above]
```

## Cross-Feature Coherence Checklist

Run after processing questionnaire answers (Step 8).

```markdown
## Coherence Check: YYYY-MM-DD

### Entity Coherence
- [ ] Same fields and types across all features that reference the same entity?
- [ ] Same aggregate root assignments?
- [ ] Same ownership (which context owns each entity)?
→ Conflict: [describe, or "none"]

### Event Coherence
- [ ] Every consumed event has a producer feature?
- [ ] Schemas consistent between producer and consumers?
- [ ] No circular event dependencies?
→ Conflict: [describe, or "none"]

### Dependency Coherence
- [ ] All required entities exist in a prior feature?
- [ ] No two features modify the same table in conflicting ways?
→ Conflict: [describe, or "none"]

### Constraint Coherence
- [ ] All features respect architectural constraints (multi-tenancy, security, migration policies)?
→ Conflict: [describe, or "none"]

### Scope Coherence
- [ ] Every spec section covered by at least one feature?
- [ ] No duplicate implementations across features?
→ Gap: [describe, or "none"]

### Verdict: [RED | YELLOW | GREEN]
```

## Question Categories

Reference for generating category-appropriate questions per feature type.

### Identity/Auth features
- Role hierarchy, tenant isolation model, API key scoping, SSO fallback behavior
- Session management, token expiry, refresh strategy
- Admin vs self-service operations

### Data ingestion features
- Payload format validation, deduplication strategy, failure mode (reject vs partial accept)
- Batch boundaries, max payload size, concurrent ingestion limits
- Idempotency guarantees

### Analysis/computation features
- Trigger mechanism (on-demand, event-driven, scheduled)
- Scope (per-tenant, per-entity, global)
- Staleness tolerance, cache invalidation, conflict resolution
- Resource limits (max computation time, max memory)

### Policy/governance features
- Evaluation trigger (on write, on read, scheduled)
- Override mechanism (admin override, emergency bypass)
- Retroactivity (apply to existing data?)
- Default behavior when no policy matches

### Integration features
- Direction (push, pull, bidirectional)
- Conflict resolution strategy
- Rate limits (inbound and outbound)
- Credential storage and rotation
- Retry and circuit breaker behavior
