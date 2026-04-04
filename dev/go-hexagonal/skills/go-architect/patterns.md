# Go Architect Patterns

Reference patterns for go-architect task design. Each section is self-contained so agents can read only the section they need.

---

## Hexagonal Directory Structure

```
internal/<context>/
    domain/                          # Pure business logic — no imports from app/, inbound/, or outbound/.
                                     # This is the innermost layer; everything else depends on it.
    domain/repositories/<entity>/    # PORT interfaces (repository contracts).
                                     # These define WHAT operations exist, not HOW they're implemented.
                                     # One package per entity keeps interfaces focused and testable.
    domain/repositories/<entity>/<entity>test/  # Mock structs + reusable contract test functions.
                                     # Mocks use function-based pattern (panic on unset) so missing
                                     # expectations fail loudly instead of returning zero values silently.
                                     # Contract tests are called by both unit tests and integration tests.
    domain/<port>/<port>test/        # Mock structs + contract tests for non-repository, non-service ports.
                                     # Same pattern as repositories: MockXxx + XxxContractTesting.
                                     # Use this for any domain port that is neither a repository nor a service:
                                     # stream sources, event emitters, tool handlers, notifiers, etc.
                                     # Examples: domain/streamsource/streamsourcetest/, domain/toolhandler/toolhandlertest/
                                     # NEVER use outbound/mock/ or flat domain/mocks.go — all domain port
                                     # test doubles live in domain/<port>/<porttest>/.
    domain/service/                  # Domain service interfaces — only needed when business logic
                                     # spans multiple entities and doesn't belong to a single entity's methods.
    domain/uow/                      # Unit of Work interface (transaction boundary).
                                     # Lives in domain because it's a PORT — the app layer depends on
                                     # the interface, and outbound provides the implementation.
    app/                             # Application services (orchestration layer).
                                     # Coordinates domain objects and ports. No business logic here —
                                     # only "call repo A, then call repo B, handle errors."
                                     # Dependencies injected via Config struct, not globals.
    inbound/<adapter>/               # Protocol-specific handlers (driving adapters).
                                     # One package per protocol: http/, mcp/, grpc/, ws/, amqp/.
                                     # Thin layer: parse request, call app service, write response.
                                     # All business logic lives in app/ or domain/, never here.
    inbound/<adapter>/converters/    # Request/response type converters and validation.
                                     # Translates between protocol-specific types and domain types.
                                     # Keeps domain types clean of JSON tags and API concerns.
                                     # Each protocol has its own converters — never shared across adapters.
    outbound/<adapter>/              # Database/queue/cache implementations (driven adapters).
                                     # Implements the repository interfaces from domain/repositories/.
                                     # Each adapter technology gets its own package (e.g., postgres/, redis/).
    outbound/<adapter>/migrations/   # Numbered migration files (if applicable).
                                     # Use sequential numbering (001_, 002_) and keep migrations idempotent.
                                     # Each file handles one schema change for easy rollback tracking.
```

**Adaptation notes:**
- Replace `<context>` with the bounded context name (e.g., `server`, `billing`, `auth`).
- Replace `<entity>` with the domain entity (e.g., `project`, `notification`, `user`).
- Replace `<adapter>` with the technology or protocol (e.g., `postgres`, `redis`, `rabbitmq` for outbound; `http`, `mcp`, `grpc`, `ws` for inbound).
- Not every context needs every directory — only create what the feature requires. Don't scaffold empty packages.

---

## Unit of Work Interface

```go
// domain/uow/uow.go
//
// The UoW interface is a PORT — it lives in the domain layer so the app layer
// can depend on it without importing outbound packages. The outbound adapter
// provides the concrete implementation using the database driver's transaction support.

type UnitOfWork interface {
    // Do executes fn inside a transaction. If fn returns an error, the transaction
    // is rolled back. If fn returns nil, the transaction is committed.
    //
    // The fn receives a scoped provider that gives access to transactional repositories.
    // This means every repository call inside fn shares the same transaction — either
    // ALL writes succeed or NONE do. This is critical for data consistency.
    //
    // IMPORTANT: Do NOT call non-transactional repository methods inside fn.
    // Only use the repos provided by the callback — they are the transactional versions.
    Do(ctx context.Context, fn func(ctx context.Context, repos Repositories) error) error
}

// Repositories provides access to all repositories within the transaction scope.
// Each repository returned here operates within the same transaction.
//
// When adding a new entity that participates in multi-repo operations:
// 1. Add a method here returning the repository interface
// 2. Update the outbound UoW implementation to construct the transactional repo
// 3. Update mock UoW for tests
//
// Only include repositories that actually need transactional coordination.
// Not every repository in the system needs to be here.
type Repositories interface {
    Notifications() notification.NotificationRepository
    Projects() project.ProjectRepository
    // Add more as needed — but only repos that participate in cross-repo transactions
}
```

**Adaptation notes:**
- Add only the repository methods your feature needs for atomic operations.
- If your feature only touches one repository, skip UoW entirely. Single-repo operations don't need transaction coordination.
- The outbound implementation wraps `sql.Tx` (for SQL) or `mongo.Session` (for MongoDB) and passes it to each repository constructor.

---

## Unit of Work App Service Usage

```go
// Example: an app service method that atomically modifies two repositories.
// Without UoW, a failure between the two writes would leave data inconsistent.

func (a *App) TransferOwnership(ctx context.Context, projectID, newOwnerID types.ID) error {
    // a.uow is injected via the App's Config struct — never constructed inline.
    // The UoW handles BEGIN/COMMIT/ROLLBACK automatically.
    return a.uow.Do(ctx, func(ctx context.Context, repos uow.Repositories) error {
        // Step 1: Read current state INSIDE the transaction.
        // This ensures we get a consistent snapshot (no concurrent modifications).
        project, err := repos.Projects().FindByID(ctx, projectID)
        if err != nil { return err }

        // Step 2: Apply domain logic.
        // The domain model validates the state change — app layer just coordinates.
        project.OwnerID = newOwnerID

        // Step 3: Persist the change using the TRANSACTIONAL repo.
        // If this fails, the whole transaction rolls back — no partial writes.
        if err := repos.Projects().Update(ctx, project); err != nil { return err }

        // Step 4: Second write — also transactional.
        // If THIS fails, the project update above is also rolled back.
        // That's the whole point of UoW: all-or-nothing across repos.
        return repos.Notifications().Create(ctx, projectID, domain.Notification{
            Type: domain.NotificationTypeOwnerChanged,
            Message: "Project ownership transferred",
        })
    })
}
```

**Adaptation notes:**
- Always read state INSIDE the `Do` callback, not before it. Reading outside means you're checking stale data.
- Each `repos.Xxx()` call returns the same interface as the non-transactional version — the app layer code doesn't know it's transactional.
- Error handling: just `return err` from inside the callback. The UoW implementation handles rollback.

---

## TASKS.md Template

```markdown
# Tasks for Feature: [Name]
<!-- Name matches the feature slug from FEATURE.md -->

## File Manifest
<!-- Complete inventory of every file this feature touches.
     The runner uses this to detect conflicts between parallel tasks.
     Missing files here = mysterious merge conflicts later. -->

### Files to CREATE
- path/to/file.go — [purpose: what this file contains and why it exists]
<!-- Use full relative paths from repo root: internal/server/domain/models.go
     Not abbreviated paths. Agents need exact paths for file reads. -->

### Files to UPDATE
- path/to/file.go — [what changes and why — be specific about which functions/types change]
<!-- "Update models.go" is useless. "Add CommentID type and Comment struct to models.go" is actionable. -->

### Files to DELETE
- path/to/file.go — [why this file is being removed]
<!-- Rare, but important to track. Agents need to know what's going away. -->

## Task List
<!-- Task IDs are sequential and stable — never renumber.
     If advisors add tasks later, they get the next available ID.
     The "Depends On" column drives execution order. -->

| ID | Title | Skill | Phase | Model | Depends On | Status |
|----|-------|-------|-------|-------|------------|--------|
| task-1 | Scaffold all stubs and interfaces | go-scaffolder | scaffold | sonnet | — | pending |
| task-2 | [ADVISOR] Review architecture and security | go-reviewer | advisor | sonnet | task-1 | pending |
| task-3 | [RED] Contract tests for XxxRepository | go-test-writer | red | sonnet | task-1 | pending |
| task-4 | [GREEN] Implement XxxRepository | go-dev | green | sonnet | task-3 | pending |
| task-5 | [RED] App layer tests for XxxService | go-test-writer | red | sonnet | task-4 | pending |
| task-6 | [GREEN] Implement XxxService | go-dev | green | sonnet | task-5 | pending |
| task-7 | [RED] Converter tests | go-test-writer | red | sonnet | task-1 | pending |
| task-8 | [GREEN] Implement converters | go-dev | green | sonnet | task-7 | pending |
| task-9 | [RED] E2E API tests | go-test-writer | red | sonnet | task-6,task-8 | pending |
| task-10 | [GREEN] Implement HTTP handlers | go-dev | green | sonnet | task-9 | pending |
| task-11 | [ADVISOR] Review queries, indexes, and data layer | go-reviewer | advisor | sonnet | task-4,task-10 | pending |
| task-12 | [MIGRATION] Data migration (if needed) | go-migrator | migration | sonnet | task-4 | pending |
<!-- Phase tags: scaffold, red, green, advisor, migration
     Skill must match an available go-* skill name exactly.
     Model: haiku, sonnet, or opus — see "Model Assignment Guidelines" in SKILL.md.
     Status: pending | in-progress | done | failed | skipped
     Dependencies are comma-separated task IDs (no spaces after comma). -->
```

**Adaptation notes:**
- Adjust the task list to match your feature's actual layers. Not every feature needs converters, migrations, or E2E tests.
- Red-green pairs must be 1:1. Every red task has exactly one green partner.
- Advisors depend on the tasks they review. Place them after the relevant green tasks.
- Keep task titles short but descriptive. The title appears in logs and status reports.

---

## Individual Task File Template

```markdown
# task-<id>: [Title]
<!-- Title must match the TASKS.md table exactly for traceability. -->

## Skill: [go-scaffolder|go-test-writer|go-dev|go-reviewer|go-fixer|go-migrator]
<!-- This determines which agent runs the task. Must be an exact skill name. -->

## Phase: [scaffold|red|green|advisor]
<!-- scaffold = create stubs, red = write failing tests, green = make tests pass, advisor = review -->

## Model: [haiku|sonnet|opus]
<!-- The runner dispatches this task with this model. See "Model Assignment Guidelines" in go-architect SKILL.md. -->

## Depends On: [task-X, task-Y]
<!-- The runner won't start this task until all dependencies are "done".
     If a dependency fails, this task is blocked until the failure is resolved. -->

## Relevant Code Files

List every file the subagent needs to read to do this task:
<!-- These are READ targets — files the agent examines for patterns and context.
     Only list files that EXIST. Never reference files that haven't been created yet.
     The agent uses these to pattern-match conventions: naming, error handling, structure. -->

- `internal/server/domain/models.go` — existing domain types (read for context)
  <!-- WHY: Agent needs to see how existing typed IDs and structs are defined
       to create new ones following the same conventions. -->
- `internal/server/domain/repositories/comments/comments.go` — similar repository interface pattern
  <!-- WHY: Agent copies this interface structure for the new entity's repository.
       Method signatures, parameter order, return types should match. -->
- `internal/server/domain/repositories/comments/commentstest/contract.go` — similar mock/contract pattern
  <!-- WHY: Agent needs to see the function-based mock pattern and how contract
       test functions are structured for reuse across unit and integration tests. -->

## Parent Task Summaries

> Read these summaries from completed dependency tasks for context:
> - `.plan/<feature-slug>/task-<dep-id>_SUMMARY.md`
<!-- Summaries are written by the runner after each task completes.
     They contain what was created, what decisions were made, and any deviations.
     The agent MUST read these to understand what exists before starting work. -->

## Description

[Detailed description of what the subagent must do]
<!-- Be explicit. The subagent only sees THIS file — it doesn't have the full
     TASKS.md context or the FEATURE.md. Everything it needs must be here
     or referenced in "Relevant Code Files" / "Parent Task Summaries". -->

## Files to Create/Modify

- `path/to/new_file.go` — CREATE: [what it contains]
- `path/to/existing.go` — MODIFY: [what to add/change]
<!-- The runner uses this list to detect conflicts between parallel tasks.
     If two tasks list the same file, they must be sequential (set dependencies).
     Be exhaustive — missing a file here causes merge conflicts. -->

## Acceptance Criteria

- [ ] [Specific, verifiable criterion]
- [ ] `go build ./...` passes
- [ ] [For red: tests compile but FAIL — this proves the tests actually test something]
- [ ] [For green: all previously-red tests PASS — name the specific test functions]
- [ ] [For scaffold: all tests PASS or SKIP — no failures allowed]
<!-- Criteria must be machine-verifiable where possible.
     "Code is clean" is not verifiable. "go vet ./... passes" is. -->
```

**Adaptation notes:**
- Every task file needs all sections, even if some are short. The agent relies on the structure.
- "Relevant Code Files" is the most important section for quality. Good examples lead to good output.
- Acceptance criteria should name specific test functions when possible (e.g., "TestCommentRepository_FindByID passes").

---

## E2E Testing Requirements

Include this section verbatim in every E2E test task's Description. The subagent needs explicit instructions because it won't have the skill context.

```markdown
## E2E Testing Requirements

This task uses testcontainers to run tests against real infrastructure. Do NOT use mocks
or in-memory implementations for e2e tests.
<!-- The entire point of e2e tests is to prove the REAL stack works together.
     Mocks defeat this purpose entirely — they test your assumptions, not reality. -->

### Setup pattern (in TestMain):
1. Start testcontainers for all external dependencies (database, message queue, cache, etc.)
   <!-- Use the testcontainers-go module for each technology: testcontainers-go/modules/postgres, etc.
        TestMain runs once per package — container startup cost is amortized across all tests. -->
2. Get connection strings and create client pools/connections
   <!-- Extract host:port from the container, build DSN/URL, create pool with production-like settings.
        Use the same connection pool configuration as production (pool size, timeouts). -->
3. Run ALL migrations/schema setup in order
   <!-- Apply every migration file sequentially. This proves migrations actually work —
        syntax errors, constraint conflicts, and ordering issues surface here, not in production. -->
4. Seed test data: insert known entities with fixed IDs for deterministic assertions
   <!-- Use UUID constants (not random UUIDs) so test assertions are stable.
        Define seed data as package-level vars for reuse across test functions. -->
5. Build the real app with real repositories/clients (not mocks)
   <!-- Wire the same Config struct used in production, but with test connection strings.
        This proves the dependency injection and initialization code works. -->
6. Start an `httptest.Server` with the real router
   <!-- httptest.Server gives you a real HTTP endpoint for making requests.
        Use the same router/middleware chain as production. -->
7. `t.Cleanup()` to close server, connections, and terminate containers
   <!-- Cleanup runs even on test failure. Order matters: close server first,
        then connections, then containers. Reverse order of creation. -->

### Required dependency:
- `github.com/testcontainers/testcontainers-go` (plus the relevant modules for your
  infrastructure: postgres, redis, rabbitmq, kafka, etc.)
  <!-- Add to go.mod with `go get`. Each infrastructure type has its own module. -->

### Seed data must include:
- At least 2 scopes/tenants (for IDOR testing)
  <!-- Scope A = the "active" tenant for most tests. Scope B = the "other" tenant
       used to verify cross-tenant isolation. Use descriptive names in constants. -->
- Multiple entities in scope A (for list/filter/search testing)
  <!-- At least 3 entities: enough to test pagination, sorting, and filtering.
       Include entities with different states/types to cover filter combinations. -->
- At least 1 entity in scope B (for cross-scope isolation testing)
  <!-- This entity must be invisible from scope A's perspective.
       Every FindByID, Update, Delete test should verify scope B data is unreachable. -->

### Tests must cover:
- Full CRUD lifecycle against real infrastructure
  <!-- Create → Read → Update → Read again → Delete → verify gone.
       This proves the happy path works end-to-end. -->
- IDOR: access scope B's data from scope A's endpoint → 404
  <!-- This is the most critical security test. If this fails, any user can access
       any entity by guessing IDs. Test EVERY endpoint that takes an entity ID. -->
- Search/filter with real data (proves indexes, full-text search, etc. work)
  <!-- Test with the seeded data. Verify result count, order, and content.
       This catches missing indexes (slow queries) and broken search configurations. -->
- Empty results return `[]` not `null`
  <!-- JSON clients break on null arrays. Always return empty array.
       Test by querying a filter that matches nothing. -->
- Error responses with structured JSON
  <!-- Verify the error response body matches {"error":{"code":"...","message":"..."}}.
       Test invalid IDs, missing required fields, and constraint violations. -->
- Message queue integration (if applicable): verify messages are published/consumed
  <!-- Start a real queue container, publish from the handler, consume in the test.
       Verify message content and delivery guarantees. -->
- Cache behavior (if applicable): verify cache hits/misses/invalidation
  <!-- Start a real cache container. Verify: cold miss → populate → hit → invalidate → miss.
       Test TTL behavior if applicable. -->
```

---

## Security Constraints

Include this section verbatim in every task file. Subagents only see their own task file, so security rules must be embedded in each one.

```markdown
## Security Constraints
- Repository methods that operate on tenant/scope-scoped entities MUST include the scoping
  ID as a parameter (e.g., projectID, orgID, tenantID in FindByID, Update, Delete, etc.)
  — this prevents cross-tenant data access (IDOR).
  <!-- This is the #1 security rule. Without scope parameters, any user can access any
       entity by guessing its ID. The scope parameter forces the query to filter by both
       entity ID AND scope ID. -->
- Parameter order: broad to narrow — (scopeID, entityID) — never reversed. This keeps
  all repositories consistent.
  <!-- Consistent parameter order means agents can pattern-match from existing code.
       Inconsistent order leads to bugs where scope and entity IDs get swapped. -->
- Database queries MUST filter by both entity ID AND scope ID. Never query by entity
  ID alone.
  <!-- Even if entity IDs are globally unique, always filter by scope. Defense in depth —
       a UUID collision or ID reuse across tenants must not leak data. -->
- Contract tests MUST include a "wrong scope" test: create in scope A, attempt access
  from scope B → must return not-found error.
  <!-- This test proves the IDOR protection works at the repository level.
       It catches missing WHERE clauses before the code reaches production. -->
- Error responses MUST use structured JSON: `{"error":{"code":"...","message":"..."}}`.
  Never use http.Error() with plain text.
  <!-- Structured errors let clients programmatically handle error codes.
       Plain text errors break API contracts and expose internal details. -->
- All user input MUST be validated: format validation for IDs, length limits for strings,
  type validation for enums.
  <!-- Validate at the inbound layer (converters/handlers) before data reaches the app layer.
       Domain types should be constructed through validated constructors where possible. -->
- Migration/schema DDL MUST be idempotent. Non-idempotent migrations fail on re-run.
  <!-- Use CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS, etc.
       Migrations may run multiple times in dev environments or during rollback recovery. -->
- Repository methods MUST distinguish "not found" from other database errors. Only map
  the driver's specific "no rows" error to domain not-found. Never collapse all DB errors
  into not-found — a timeout or connection error must propagate as a 500, not a 404.
  <!-- Check for sql.ErrNoRows (or equivalent) specifically. Every other error type
       (connection refused, timeout, syntax error) must bubble up as an internal error
       so the handler returns 500, not a misleading 404. -->
- E2E tests MUST use testcontainers (real database/queue/cache), NOT mocks. Seed the
  datastore with known data. This is the only way to prove migrations, queries,
  constraints, and indexes actually work.
  <!-- Mocks in e2e tests are a false safety net. They test your assumptions about the
       database, not the database itself. Real containers add ~10s startup but catch
       real bugs that mocks never will. -->
```
