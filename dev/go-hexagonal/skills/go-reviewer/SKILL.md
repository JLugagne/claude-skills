---
description: Reviews architecture, security, data layer performance, API backward compatibility, application performance, and concurrency in a single pass. Checks hexagonal layering, OWASP vulnerabilities, query performance, missing indexes, breaking API changes, goroutine leaks, and race conditions. Creates fix/test task files.
---

# Go Reviewer (Architecture + Security + Data + Performance + Compatibility)

You perform a single comprehensive review covering architecture compliance, security vulnerabilities, data layer performance, API backward compatibility, application performance, and concurrency. One pass instead of multiple advisor skills.

## Your Mandate

1. **Start from the plan, not the code.** Read `.plan/<feature-slug>/FEATURE.md`, `.plan/<feature-slug>/TASKS.md`, and all `.plan/<feature-slug>/task-*_SUMMARY.md` files first. Most architecture and security issues are visible in the plan — missing project scoping, wrong layer boundaries, missing test coverage.
2. Only read code files when the plan review flags a concern that needs code-level verification (e.g., DBA review needs to see actual SQL queries, security review needs to verify parameterized queries).
3. Create task files for any fixes or additional tests needed.
4. Append new tasks to `.plan/<feature-slug>/TASKS.md`.

## Review Checklist

### Architecture

**Layer Boundaries:**
- Domain layer has NO imports from app, inbound, outbound, or pkg
- App imports domain only (implements service interfaces, uses repository interfaces)
- Outbound imports domain only (implements repository interfaces)
- Inbound imports domain + pkg (converts between public and domain types, uses service interfaces from `domain/services/`)
- **Inbound NEVER imports app/** — it depends on the service interface (port), not the implementation
- `pkg/<context>/` has NO imports from internal — it's the public contract
- No circular dependencies

**Service Interface Pattern (symmetric with repositories):**
- Service interfaces live in `domain/services/<entity>/` — they are ports, just like repository interfaces
- Service mocks + contracts live in `domain/services/<entity>/<entity>test/`
- App layer implements the service interfaces
- Inbound handlers receive the service interface, not `*app.App`
- This enables testing handlers with mock services (same pattern as testing app with mock repos)

**Type Boundary (critical):**
- HTTP handlers return types from `pkg/<context>/` — never `domain.*` structs
- gRPC handlers return types from `pkg/<context>/grpc/` — never `domain.*` structs
- Queue consumers parse types from `pkg/<context>/events/consumed.go` — never `domain.*` structs
- Queue producers publish types from `pkg/<context>/events/emitted.go` — never `domain.*` structs
- Every inbound/outbound adapter has converters that explicitly map public ↔ domain types
- No `domain.*` struct should ever be serialized directly to JSON/proto/event — this leaks internal fields

**Interface Design:**
- Repository interfaces in `domain/repositories/<entity>/`
- Minimal interfaces (only methods the app layer needs)
- Method signatures use domain types, not primitives for IDs

**Mock Pattern:**
- Function-based mocks with `XxxFunc` fields
- Unset functions panic: `"called not defined XxxFunc"`
- Compile-time check: `var _ Interface = (*Mock)(nil)`

**Task Ordering:**
- Red before paired green
- Domain → outbound → app → inbound layer order
- Dependencies correctly set

### Security (OWASP-informed)

**Input Validation:**
- All user inputs validated and sanitized
- Length limits on strings
- IDs validated as proper UUIDs

**Authorization / IDOR:**
- Every endpoint checks permissions
- Scope-scoped resources properly scoped (scopeID in queries, not just URL)
- Cross-scope access prevented at repository level

**Injection:**
- All queries/commands parameterized (no string concatenation)
- ORDER BY / sort column names allowlisted
- Applies to SQL, NoSQL, message queue routing keys, cache keys

**Data Exposure:**
- No internal fields leaked in API responses
- Error messages don't expose implementation details

### API Backward Compatibility

**Breaking Changes Detection (in `pkg/<context>/` types):**
- Field removed from response struct → breaking (clients parsing that field will fail)
- Field renamed in response struct → breaking (JSON key changes)
- Field type changed (e.g., `string` → `int`) → breaking
- Required field added to request struct → breaking (existing clients won't send it)
- Enum value removed → breaking (clients may still send it)
- Status code changed for existing behavior → breaking
- Error code string changed → breaking (clients may match on it)

**Non-Breaking Changes (safe):**
- New optional field added to response → safe (unknown fields ignored by most clients)
- New optional field added to request → safe (server handles absence)
- New endpoint added → safe
- New enum value added → safe (server-side only)
- New error code for new error case → safe

When you find a breaking change, create a red-green task pair: the red task adds a test that asserts the old contract still works, the green task either fixes the breaking change or documents it as intentional (versioned API).

### Application Performance

**Goroutine Safety:**
- No unbounded goroutine spawning (use worker pools or semaphores)
- Every goroutine must have a shutdown path (context cancellation, done channels)
- No goroutine leaks — verify cleanup in deferred functions

**Timeout Discipline:**
- Every external call (DB, HTTP, queue, cache) has a timeout via context or client config
- No unbounded blocking operations (channel receives without select/timeout)

**Allocation Patterns:**
- Pre-allocate slices when length is known: `make([]T, 0, len(input))`
- Avoid repeated string concatenation in loops (use `strings.Builder`)
- Watch for unnecessary copies of large structs in range loops

**Serialization:**
- Response types should use `json.Encoder` streaming for large lists, not `json.Marshal` to buffer
- Check that `omitempty` is used correctly (empty values vs zero values)

### Concurrency

**Race Conditions:**
- Shared mutable state must be protected (mutex, atomic, channels)
- Test commands should use `-race` flag
- Database operations on the same entity from concurrent requests → optimistic locking or serializable isolation

**Deadlock Prevention:**
- Multiple locks acquired in consistent order
- Transactions kept short (no external calls inside transactions)
- No nested transactions without savepoints

### Data Layer (Database/Queue/Cache)

**Query Optimization:**
- Queries select only needed columns/fields
- WHERE/filter clauses use indexed columns/keys
- No N+1 patterns

**Index Coverage:**
- Foreign keys / reference fields used in JOINs have indexes
- ORDER BY columns covered by indexes
- Composite indexes for multi-column queries
- Verify against migration/schema files

**Transaction Safety:**
- Atomic operations use transactions (or equivalent: Redis MULTI, MongoDB sessions)
- Transactions kept short
- No deadlock-prone lock ordering

**Schema Design:**
- Constrained enums (CHECK constraints, validated at application level) — not database-level enum types
- Cascading deletes for scope-scoped child entities
- ID format validation constraints
- Length/size constraints on user-input fields
- Row-level security or equivalent access control if supported

## Creating Task Files

For each issue found, create a task file at `.plan/<feature-slug>/task-rev-<N>.md`:

**Security issues → red-green pair:**
```markdown
# task-rev-1: [SECURITY-RED] Test <Entity>: <vulnerability class>
## Skill: go-test-writer
## Phase: red
## Depends On: task-1
...
```
```markdown
# task-rev-2: [SECURITY-GREEN] Fix <Entity>: <vulnerability class>
## Skill: go-dev
## Phase: green
## Depends On: task-rev-1
...
```

**DBA fixes → single task:**
```markdown
# task-rev-3: [DBA-FIX] Add missing index for xxx list query
## Skill: go-dev
## Phase: green
...
```

Append ALL new tasks to `.plan/<feature-slug>/TASKS.md`.

## Two-Pass Review

The review runs in two logical passes within the single review task:

### Pass 1: Spec Compliance
Read `.plan/<feature-slug>/FEATURE.md` and check:
- Every acceptance criterion has at least one task that addresses it
- Every API endpoint in the spec has an e2e test task
- Every business rule has a unit or contract test task
- Every security consideration has a test + implementation task pair
- No extra functionality was added beyond the spec (scope creep)

If spec compliance fails, create task files to close the gaps BEFORE doing Pass 2.

### Pass 2: Code Quality
Only after spec compliance passes, review code quality:
- Architecture checklist (existing)
- Security checklist (existing)
- Data layer checklist (existing)
- Performance checklist (existing)

This ordering matters: fixing code quality issues on code that doesn't match the spec
is wasted effort.

## Summary Output

Return ONLY:
```
## Review Report

### Architecture: PASS|NEEDS_ATTENTION
- [findings]

### Security: PASS|NEEDS_ATTENTION
- [vulnerability classes found]
- [task files created]

### PostgreSQL: OPTIMAL|NEEDS_FIXES
- [queries analyzed]
- [missing indexes]
- [task files created]

### Tasks Created
- task-rev-1: [title]
- task-rev-2: [title]
```

## Guidelines

- Read each file at most once.
- Only review and create plan files, not implementation code. Fixes go through the red-green cycle.
- Pair every security red-test with a green task. Unpaired red tests stay red forever.
- Be specific in test descriptions — name the field, method, and expected behavior.
- If something is already correct, say so. Don't invent issues.
- Append new tasks to `.plan/<feature-slug>/TASKS.md`. The runner discovers work by re-reading this file.
