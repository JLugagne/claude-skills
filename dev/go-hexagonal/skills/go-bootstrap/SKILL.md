---
name: go-bootstrap
description: Bootstraps a new Go project from scratch with hexagonal architecture, testcontainers, CI pipeline, and the full skill/agent suite installed. Use when starting a new project or microservice.
invoke: user
trigger: never
tools:
  - Agent
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
---

# Go Project Bootstrap

You scaffold a complete Go project from scratch following hexagonal architecture, ready for feature development with the full skill/agent pipeline.

## Interview (quick — 3-5 questions max)

Ask the user:
1. **Project name** and Go module path (e.g., `github.com/org/service`)
2. **Infrastructure**: Which external dependencies? (PostgreSQL, Redis, RabbitMQ, Kafka, MongoDB, etc.)
3. **API type**: HTTP (gorilla/mux, chi, stdlib), gRPC, or both?
4. **First bounded context name** (e.g., `server`, `identity`, `billing`)
5. **Any existing conventions** to follow? (error format, ID type, auth middleware, logging library)

## What You Create

Read [patterns.md](patterns.md) for the full project structure and all code patterns. Use each section as a template when creating the corresponding file.

### Foundation Code

For each pattern below, read the corresponding section in [patterns.md](patterns.md) and adapt to the user's answers:

- **Project Structure** — full directory tree
- **Domain Error Pattern** — `domainerror.New(code, message)` in `domain/errors/`
- **Typed ID Pattern** — `type ProjectID string` with UUID in `domain/types/`
- **Service Interface Pattern** — empty interfaces in `domain/services/<entity>/` (inbound ports)
- **Repository Interface Pattern** — empty interfaces in `domain/repositories/<entity>/` (outbound ports)
- **Event Types Pattern** — consumed.go and emitted.go in `pkg/<context>/events/`
- **init.go Wiring** — Setup() creates repos, app, handlers; passes service interface, not `*app.App`
- **main.go** — minimal: env vars + `Setup()` + `ListenAndServe`
- **Structured Logging** — App struct with `*slog.Logger` dependency
- **Error Response Helper** — `writeErrorJSON()` for structured JSON errors
- **Health Check** — `GET /health` returning `{"status":"ok"}`
- **E2E Test Setup** — `TestMain` with testcontainers boilerplate
- **Makefile** — build, test, lint, lint-arch, lint-pipeline, migrate targets
- **Architecture Lint Config** — `.go-arch-lint.yml` enforcing hexagonal layer dependencies
- **CI Pipeline** — GitHub Actions with testcontainers
- **Hooks** — auto-format on edit, build-check before commit

- **Project Map Skeleton** — `.claude/skills/doc-project/SKILL.md` (minimal table of contents with the first context) and `.claude/skills/doc-project/conventions.md` (patterns established during bootstrap). Context docs in `.claude/skills/doc-project/contexts/` are created by go-finish as features arrive.

Key principles:
- Inbound handlers receive the service **interface** from `domain/services/`, not `*app.App`
- `main.go` has zero business logic — E2E tests call `Setup()` directly
- Hooks are deterministic — auto-formatting and build checks run guaranteed, not advisory

### Install Skill/Agent Suite

Copy all 17 agent files to `.claude/agents/`:
- `go-brainstorm.md` — Problem exploration (approach validation, scope check)
- `go-pm.md` — Product manager (spec interrogation, aggregate identification)
- `go-architect.md` — Architecture design (TASKS.md generation)
- `go-api-designer.md` — HTTP API design (routes, types, validation)
- `go-scaffolder.md` — Scaffolding (stubs, interfaces, mocks, skipped tests)
- `go-test-writer.md` — Red phase TDD (failing tests)
- `go-dev.md` — Green phase TDD (implementation + observability)
- `go-reviewer.md` — Review (architecture, security, data, performance, compatibility)
- `go-migrator.md` — Data migrations (backfill, transform, split)
- `go-fixer.md` — Circuit breaker recovery (fresh-perspective fixes)
- `go-debugger.md` — Systematic root cause investigation (escalation from fixer)
- `go-runner.md` — Task execution (dispatch, validate, report)
- `go-finish.md` — Feature closure (verification, acceptance criteria, integration)
- `go-refactor.md` — Safe refactoring (document, lock, rewrite)
- `go-product-manager.md` — Product decomposition (spec → ordered features → sequential execution)
- `go-retrospective.md` — Feedback analysis (interactive questionnaire, skill improvement proposals)
- `go-bootstrap.md` — This file

## Verification

After bootstrapping:
1. `go build ./...` — passes
2. `go test -race ./... -short` — health check test passes
3. `docker-compose up -d` — infrastructure starts
4. `curl localhost:<port>/health` — returns `{"status":"ok"}`
5. `.claude/agents/` has 17 agent files
6. `go-arch-lint check` — zero violations (architectural boundaries enforced)
7. `make lint-pipeline` — all skills and agents referenced in the pipeline exist
8. `domain/services/` directory exists (inbound port interfaces)
9. `domain/repositories/` directory exists (outbound port interfaces)
10. `pkg/<context>/events/` directory exists (event contracts)
11. `.claude/skills/doc-project/SKILL.md` exists (project map skeleton)

## After Bootstrap

Tell the user: "Project is ready. Describe your first feature and I'll plan and implement it using the full skill pipeline."

The go-pm skill takes over from here for feature development.
