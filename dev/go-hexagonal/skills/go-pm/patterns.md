# Go PM Patterns

## feature-md-template

The FEATURE.md template is the single source of truth for all downstream skills. Every section directly drives task generation by go-architect.

```markdown
# Feature: [Name]

## Description
[1-2 sentences]
<!-- Keep this concise — go-architect uses it for task naming and PR descriptions -->

## Entities & Aggregates
- **[Entity]** (aggregate root): [fields and types]
  - Invariants:
    - [Rule the root enforces — e.g., "cannot receive notifications when archived"]
    <!-- Each invariant becomes a contract test assertion in go-test-writer -->
    - [Rule — e.g., "max 100 active tasks"]
  - Validation methods: [e.g., `CanReceiveNotification() error`, `CanAddTask() error`]
  <!-- These methods are scaffolded on the domain model by go-scaffolder -->
- **[ChildEntity]** (child of [Root]): [fields and types]
  - Created/modified only after root validation passes
  <!-- This constraint means the app service must load the root first -->
- **[IndependentEntity]** (aggregate root): [fields and types]
  - Invariants: [or "none — simple CRUD"]
  <!-- Simple CRUD entities get a simpler task set — don't over-model -->

For simple CRUD entities with no parent constraints, mark them as their own aggregate root with no invariants. Not every entity needs complex aggregate modeling — only document invariants that actually exist.

## API Endpoints
- [METHOD /path]: [description]
  - Request: [shape]
  - Response: [shape]
  - Errors: [codes and conditions]
  <!-- go-api-designer expands these into full endpoint specs with validation rules -->

## Events
- **Consumed**: [EventName from pkg/<context>/events/consumed.go — trigger and expected side effect]
- **Emitted**: [EventName to pkg/<context>/events/emitted.go — when published and schema]
<!-- Events crossing bounded contexts go through pkg/, not internal/ -->

## Database Changes
- [Table]: [new/altered columns, indexes, constraints]
<!-- Schema DDL goes to go-scaffolder; data migrations go to go-migrator -->

## Business Rules
1. [Rule]
2. [Rule]
<!-- Each rule becomes at least one test case in go-test-writer -->

## Security Considerations
- All repository methods for this entity MUST include the parent entity's ID (e.g., projectID) in every operation — FindByID, Update, Delete, MarkAsRead — to prevent cross-project data access (IDOR).
<!-- IDOR prevention is the #1 security concern in multi-tenant apps -->
- SQL queries MUST filter by both entity ID AND parent ID: `WHERE id = $1 AND project_id = $2`.
<!-- Without this, any user can access any entity by guessing IDs -->
- Contract tests MUST include "wrong project" scenarios.
- Error responses MUST use structured JSON: `{"error":{"code":"...","message":"..."}}`.
- App service methods that operate on child entities MUST load the aggregate root and call its validation method before proceeding. This ensures invariants cannot be bypassed by calling the child repository directly.
<!-- This is the aggregate pattern's core guarantee — don't skip it -->
- [Additional security items specific to this feature]

## Edge Cases & Error Handling
- [Case]: [expected behavior]
- [Aggregate root in invalid state]: [e.g., "CreateNotification on archived project → ErrProjectArchived"]
<!-- Each edge case maps to an error-path test -->

## Definition of Done
- [ ] [Criterion — each must be objectively verifiable]
<!-- Vague criteria like "works well" cannot be checked by go-finish -->
- [ ] All tests pass (`go test ./...`)
- [ ] Project compiles (`go build ./...`)
- [ ] E2E tests cover happy path and error cases
- [ ] Security tests cover identified sensitive functions
- [ ] Aggregate invariant tests cover root-in-invalid-state scenarios
- [ ] Database migrations are idempotent
- [ ] No regressions in existing tests
```

## dispute-resolution-agent-prompt

When resolving a spec dispute, invoke go-architect with this prompt structure. Each section tells the architect exactly what corrective tasks to create.

```
Launch Agent with subagent_type: go-architect and prompt:
A spec dispute was resolved for feature <feature-slug>.

# Ruling
<your ruling and reasoning>
<!-- Be specific: which side was right, what the correct behavior is -->

# Updated Spec
<relevant section of updated FEATURE.md>
<!-- Only include the changed sections, not the whole file -->

Read .plan/<feature-slug>/TASKS.md and create corrective tasks:
- If tests need rewriting: create a new red task for go-test-writer
  <!-- Red tasks always come before green — tests define the expected behavior -->
- If implementation needs retrying: create a new green task for go-dev with the clarification
  <!-- Include the clarification in the task so go-dev doesn't re-read the dispute -->
- Mark the disputed task as superseded in TASKS.md
  <!-- Superseded tasks are skipped by go-runner, preventing duplicate work -->
Append new tasks to .plan/<feature-slug>/TASKS.md.
```
