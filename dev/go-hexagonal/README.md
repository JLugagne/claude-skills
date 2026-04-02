---
description: Go hexagonal architecture agents and skills — TDD pipeline with red/green separation, security-first review, and structured feature planning. Benchmarked across 50+ runs.
tags:
  - golang
  - hexagonal
  - tdd
  - testcontainers
  - microservices
  - security
---

# Go Hexagonal Architecture

Production-ready Go code generation following hexagonal architecture with strict TDD. This profile provides a full agent pipeline — from feature planning through implementation, review, and refactoring.

## Pipeline Architecture

```
go-brainstorm (Opus)    — explores problem space, proposes approaches, validates direction
  └── go-pm (Opus)      — interrogates user, writes FEATURE.md + spec dispute arbitration
        └── go-architect (Opus)
              ├── go-api-designer (Sonnet)  — HTTP routes, request/response types
              ├── writes TASKS.md + task-N.md (security constraints embedded)
              └── go-runner (Sonnet)        — thin dispatcher, never writes code
                    ├── go-scaffolder        — stubs, interfaces, mocks
                    ├── go-test-writer       — red phase (unit, contract, e2e) [+ red verification]
                    ├── go-dev               — green phase (implementation) [+ go-verify evidence]
                    │     └── SPEC_DISPUTE → go-pm → go-architect → corrective tasks
                    ├── go-reviewer          — two-pass: spec compliance then code quality
                    ├── go-migrator          — data migrations (backfill, transform, split)
                    ├── go-fixer (Opus)      — circuit breaker recovery
                    ├── go-debugger (Opus)   — systematic root cause (escalation from fixer)
                    └── go-finish (Sonnet)   — verification, acceptance criteria, cleanup, integration
```

Opus plans and recovers. Sonnet executes. This split cuts cost by ~66% vs running everything on Opus.

## Getting Started

### New project

```
@go-bootstrap I want to create a new microservice called order-service
```

The `go-bootstrap` agent asks about your infrastructure (PostgreSQL, Redis, Kafka, etc.), scaffolds the full hexagonal structure, installs all agents/skills, sets up testcontainers and CI pipeline.

### New feature on an existing project

```
@go-pm Add a notification endpoint that sends emails when an order ships
```

`go-pm` interrogates the spec until it's solid, then drives the full pipeline automatically.

## Agents & Skills

| Name | Model | Role |
|------|-------|------|
| `go-bootstrap` | opus | Scaffolds new project from scratch |
| `go-pm` | opus | Feature spec interrogation, FEATURE.md, pipeline handoff |
| `go-architect` | opus | TASKS.md + task files with embedded security constraints |
| `go-api-designer` | sonnet | HTTP endpoint design, request/response types |
| `go-scaffolder` | sonnet | Stubs, interfaces, typed IDs, mocks, migration placeholders |
| `go-test-writer` | sonnet | Red phase — unit, contract, e2e (testcontainers), security tests |
| `go-dev` | sonnet | Green phase — implementation to make failing tests pass |
| `go-reviewer` | sonnet | Plan-first: architecture, security (IDOR/injection), DBA review |
| `go-fixer` | opus | Circuit breaker recovery — modifies both tests and implementation |
| `go-migrator` | sonnet | Data migrations — zero-downtime, reversible, batched, testcontainers-tested |
| `go-runner` | sonnet | Task dispatcher — coordinates subagents, never writes code, invokes go-finish after all tasks |
| `go-brainstorm` | opus | Problem exploration, approach validation, scope check |
| `go-debugger` | opus | Systematic root cause investigation through hexagonal layers |
| `go-finish` | sonnet | Feature closure — verification, acceptance criteria, cleanup, integration |
| `go-refactor` | opus | Safe rewrite: document surfaces → lock with tests → rewrite |

## Key Practices

### Hexagonal Architecture
- **Symmetric port pattern**: repository interfaces (outbound) and service interfaces (inbound) both live in `domain/`. Inbound handlers receive the service interface, never `*app.App`.
- **Type boundaries**: domain types never cross adapter boundaries. HTTP/gRPC/event adapters use their own public types in `pkg/<context>/` with explicit converters.
- **Event contracts** live in `pkg/<context>/events/consumed.go` and `events/emitted.go` — same pattern as HTTP/gRPC, never expose domain types in events.

### Testing
- **Testcontainers for all infrastructure** — unit, contract, and e2e tests. Never mock a database, queue, or cache you control. Catches migration bugs, missing indexes, FK violations, and cache invalidation issues that mocks hide.
- **Always run with `-race`**: every `go test` invocation must include `-race`.
- **Seed deterministic data** in `TestMain`. Tests assert against known state.
- **Wrong-scope tests at every layer**: create in scope A, access from scope B → 404.

### Security & Code Quality
- **IDOR protection** embedded in every task file by `go-architect`. Queries are always project-scoped — `(projectID, entityID)` parameter order, never reversed.
- **Structured JSON errors** everywhere: `{"error": {"code": "ENTITY_NOT_FOUND", "message": "..."}}`.
- **Idempotent migrations**: all DDL uses `IF NOT EXISTS`.
- **Distinguish not-found from infra errors**: only map the driver's specific not-found error to `domain.ErrNotFound` — masking all errors as 404 hides timeouts and connection failures.
- **Observability is infrastructure**: always add structured logging (with entity + scope IDs) and timeouts on external calls, regardless of test coverage.
- **API backward compatibility**: flag breaking changes in `pkg/` types (removed fields, renamed codes, changed status). Create a red-green task pair to either fix or explicitly version the break.

### Concurrency & Data
- **Optimistic locking** for concurrent writes: use a `version` field, return `ErrConcurrentModification` when `RowsAffected() == 0`.
- **Keep transactions short**: no HTTP or queue calls inside transactions. Use the outbox pattern for reliable event publishing after a DB write.
- **Data migrations via go-migrator**: zero-downtime, reversible, batched, testcontainers-tested. Always preserve old data until validation passes.

### Verification
- **Evidence before claims**: every completion claim must include actual command output (go build, go test with -race and -count=1). No stale runs, no verbal claims.
- **Two-pass review**: spec compliance checked before code quality.
- **Systematic debugging**: root cause investigation before fixes. go-debugger escalation when go-fixer circuit breaker isn't enough.
- **Feature closure**: go-finish verifies acceptance criteria line-by-line against FEATURE.md before integration.

### Pipeline & Cost
- Parallel red tasks after scaffold (typically 3–5 at once). Sequential green tasks (dependency order).
- Never inline skill files into Agent prompts — use `subagent_type` so the framework loads skills via cache (3–5x cheaper).
- Every subagent summary includes a "Files Modified" section — downstream tasks depend on it.
- **Circuit breaker**: if a subagent fails the same way twice, it must stop with `CIRCUIT_BREAK:` summary. go-fixer handles recovery with fresh context.
- **Spec disputes**: if go-dev disagrees with a test expectation, it returns `SPEC_DISPUTE:`. go-runner escalates to go-pm who arbitrates, updates FEATURE.md if needed, and invokes go-architect to create corrective tasks. The pipeline self-heals without blocking on the user.

### Context Chain
Pass all dependency summaries (`.plan/<feature-slug>/task-N_SUMMARY.md`) when dispatching downstream tasks. Summaries carry the file manifest that the original task file doesn't know about.
