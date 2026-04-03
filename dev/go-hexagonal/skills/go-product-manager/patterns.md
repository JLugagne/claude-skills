# Product Manager Patterns

Reference templates for go-product-manager. Read specific sections as needed.

## PRODUCT.md Template

Use this template when writing `.plan/PRODUCT.md` after decomposing the product spec.

```markdown
# Product: [Name]

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
**Acceptance:** [high-level definition of done — go-pm will expand this]
<!-- Keep summaries concise — go-pm will interrogate the full detail -->

### Feature 2: [Name]
...
```

## Feature Dispatch Prompt

Use this when invoking go-pm for each feature.

```
New feature for the product. Here is the context:

# Feature
[Feature detail section from PRODUCT.md]
<!-- Copy the Feature N section verbatim — go-pm needs the summary,
     entities, endpoints, events, and acceptance criteria as a starting point -->

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
