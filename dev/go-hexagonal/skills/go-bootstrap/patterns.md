# Bootstrap Code Patterns

Reference patterns for go-bootstrap. Read specific sections as needed — don't read the whole file upfront.

## Project Structure

```
<project>/
├── cmd/
│   └── <context>/
│       └── main.go                    # Entry point — calls init.Setup(), starts server
├── pkg/
│   └── <context>/
│       ├── types.go                   # PUBLIC HTTP request/response structs (JSON tags)
│       ├── events/                    # PUBLIC event contracts (async communication)
│       │   ├── consumed.go            # Events this context receives (queue consumers)
│       │   └── emitted.go             # Events this context publishes (queue producers)
│       └── grpc/                      # PUBLIC gRPC types (if applicable)
│           ├── proto/
│           │   └── <context>.proto    # Proto definitions
│           ├── <context>.pb.go        # Generated (do not edit)
│           └── <context>_grpc.pb.go   # Generated (do not edit)
├── internal/
│   └── <context>/
│       ├── init.go                    # Setup() — dependency injection, wiring, returns http.Handler
│       ├── domain/                    # PRIVATE domain models — never exposed directly
│       │   ├── errors/
│       │   │   └── errors.go          # domainerror.New pattern
│       │   ├── types/
│       │   │   └── types.go           # Typed IDs (ProjectID, etc.)
│       │   ├── uow/                   # Unit of Work interface (if needed)
│       │   ├── repositories/          # Outbound port interfaces (empty, ready for features)
│       │   └── services/              # Inbound port interfaces (empty, ready for features)
│       ├── app/
│       │   ├── config.go              # App struct with dependency injection
│       │   └── <context>_service.go   # Service stubs (implements service interfaces)
│       ├── inbound/
│       │   ├── http/                  # HTTP handlers (driving adapter)
│       │   │   ├── handlers.go        # Handler struct, RegisterRoutes, health check
│       │   │   ├── errors.go          # Structured JSON error response helpers
│       │   │   └── converters/        # pkg types ↔ domain types
│       │   ├── grpc/                  # gRPC handlers (if applicable)
│       │   │   └── converters/        # proto types ↔ domain types
│       │   └── amqp/                  # Message queue consumers (if applicable)
│       │       └── converters/        # event types ↔ domain types
│       └── outbound/
│           └── <adapter>/             # One per infrastructure dependency
│               ├── <adapter>_*.go     # Repository stubs
│               ├── converters/        # domain types → emitted event types (for queue producers)
│               └── migrations/        # Migration directory with 001_initial
├── tests/
│   └── e2e-api/
│       └── setup_test.go             # TestMain with testcontainers boilerplate
├── .claude/
│   ├── agents/                       # All typed agents
│   │   ├── go-pm.md
│   │   ├── go-architect.md
│   │   ├── go-api-designer.md
│   │   ├── go-scaffolder.md
│   │   ├── go-test-writer.md
│   │   ├── go-dev.md
│   │   ├── go-reviewer.md
│   │   ├── go-migrator.md
│   │   ├── go-fixer.md
│   │   ├── go-runner.md
│   │   ├── go-refactor.md
│   │   └── go-bootstrap.md
│   └── settings.json                 # Project settings
├── .claude/
│   └── skills/
│       └── doc-project/               # Project map (auto-loaded by Claude Code)
│           ├── SKILL.md               # Table of contents (loaded each session)
│           ├── conventions.md         # Patterns established during bootstrap
│           └── contexts/              # Per-context docs (created by go-finish per feature)
├── .feedback/                         # Pipeline feedback (created by go-finish per feature)
├── .plan/                             # Feature plans (created by go-pm, consumed by pipeline)
├── go.mod
├── go.sum
├── Makefile                          # build, test, lint, migrate targets
├── Dockerfile                        # Multi-stage build
├── docker-compose.yml                # Local dev with infrastructure containers
└── .github/
    └── workflows/
        └── ci.yml                    # Build, test (with testcontainers), lint
```

## Domain Error Pattern

```go
package domainerror

type Error struct {
    Code    string
    Message string
}

func (e *Error) Error() string {
    return e.Code + ": " + e.Message
}

func New(code, message string) *Error {
    return &Error{Code: code, Message: message}
}
```

## Event Types Pattern

```go
// pkg/<context>/events/consumed.go
package events

// Events this context receives from other bounded contexts.
// Inbound queue adapters parse these types and convert to domain types via converters.
// Add event structs here as features require them.

// pkg/<context>/events/emitted.go
package events

// Events this context publishes for other bounded contexts.
// Outbound queue adapters convert domain types to these types via converters.
// Add event structs here as features require them.
```

## init.go — Dependency Injection & Wiring

`internal/<context>/init.go` is the plumber. It creates all dependencies and wires them together. `main.go` stays minimal — it only calls `Setup()` and starts the server.

```go
// internal/<context>/init.go
package <context>

type Server struct {
    Handler http.Handler
    Pool    *pgxpool.Pool  // or whatever infrastructure clients you have
}

// Setup creates all dependencies, wires them together, and returns the server.
// This is the single place where dependency injection happens.
func Setup(ctx context.Context, databaseURL string) (*Server, error) {
    pool, err := pgxpool.New(ctx, databaseURL)
    if err != nil {
        return nil, fmt.Errorf("create connection pool: %w", err)
    }

    // Repositories (outbound adapters — implement repository interfaces from domain/repositories/)
    projectRepo := pg.NewProjectRepository(pool)

    // App service (implements service interfaces from domain/services/)
    a := app.New(projectRepo)

    // HTTP handlers (inbound adapters — receive service INTERFACE, not *app.App)
    r := mux.NewRouter()
    projectHandler := httphandlers.NewProjectHandler(a) // a satisfies ProjectService interface
    projectHandler.RegisterRoutes(r)

    // Add more inbound adapters here (gRPC, AMQP consumers, etc.)

    return &Server{Handler: r, Pool: pool}, nil
}

func (s *Server) Close() {
    s.Pool.Close()
}
```

The key principle: inbound handlers receive the service **interface** from `domain/services/`, not `*app.App`. This enables testing handlers with mock services (same pattern as testing app with mock repos).

## main.go — Minimal Entry Point

```go
// cmd/<context>/main.go — stays minimal
package main

func main() {
    databaseURL := os.Getenv("DATABASE_URL")
    srv, err := server.Setup(context.Background(), databaseURL)
    if err != nil {
        log.Fatalf("setup: %v", err)
    }
    defer srv.Close()

    log.Printf("listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", srv.Handler))
}
```

This separation matters because:
- E2E tests call `Setup()` directly with a testcontainer connection string — no need to start a real process
- `main.go` has zero business logic — it's just env vars + `Setup()` + `ListenAndServe`
- Adding a new feature means adding wiring to `init.go`, not touching `main.go`

## Structured Logging Setup

```go
// internal/<context>/app/config.go
type App struct {
    logger     *slog.Logger
    projectRepo project.ProjectRepository
}

func New(logger *slog.Logger, projectRepo project.ProjectRepository) *App {
    return &App{
        logger:      logger,
        projectRepo: projectRepo,
    }
}
```

Every service method logs with structured fields (entity IDs, scope IDs, operation name).

## Structured Error Response

```go
func writeErrorJSON(w http.ResponseWriter, status int, code, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": map[string]string{
            "code":    code,
            "message": message,
        },
    })
}
```

## E2E Test Setup (testcontainers)

```go
func TestMain(m *testing.M) {
    ctx := context.Background()
    // Start testcontainers for each infrastructure dependency
    // Connect, run migrations, seed base data
    // Start httptest.Server with real wiring via Setup()
    // t.Cleanup to tear down
    code := m.Run()
    os.Exit(code)
}
```

## Makefile

```makefile
.PHONY: build test lint migrate

build:
	go build ./...

test:
	go test -race ./... -count=1 -v

test-short:
	go test -race ./... -count=1 -short

lint:
	go vet ./...
	golangci-lint run ./...

lint-arch:
	go-arch-lint check

lint-pipeline:
	@echo "Checking pipeline consistency..."
	@for skill in go-scaffolder go-test-writer go-dev go-migrator go-reviewer go-fixer go-debugger go-pm go-finish; do \
		if [ ! -f ".claude/skills/$$skill/SKILL.md" ]; then \
			echo "ERROR: runner references skill '$$skill' but .claude/skills/$$skill/SKILL.md does not exist"; \
			exit 1; \
		fi; \
	done
	@for agent in go-brainstorm go-pm go-architect go-api-designer go-scaffolder go-test-writer go-dev go-reviewer go-migrator go-fixer go-debugger go-runner go-finish go-refactor go-bootstrap go-product-manager go-retrospective; do \
		if [ ! -f ".claude/agents/$$agent.md" ]; then \
			echo "ERROR: bootstrap lists agent '$$agent' but .claude/agents/$$agent.md does not exist"; \
			exit 1; \
		fi; \
	done
	@EXPECTED=17; \
	ACTUAL=$$(ls .claude/agents/*.md 2>/dev/null | wc -l); \
	if [ "$$ACTUAL" -ne "$$EXPECTED" ]; then \
		echo "WARNING: expected $$EXPECTED agents, found $$ACTUAL"; \
	fi
	@echo "Pipeline consistency: OK"

lint-all: lint lint-arch lint-pipeline

migrate:
	# Run migrations against local dev database
```

## Architecture Lint Config (.go-arch-lint.yml)

```yaml
version: 3
workdir: internal
allow:
  depOnAnyVendor: true

components:
  domain:
    in: "*/domain/**"
  app:
    in: "*/app/**"
  inbound:
    in: "*/inbound/**"
  outbound:
    in: "*/outbound/**"
  pkg:
    in: "../pkg/**"

commonComponents:
  - domain

deps:
  domain:
    mayDependOn: []
  app:
    mayDependOn:
      - domain
  outbound:
    mayDependOn:
      - domain
  inbound:
    mayDependOn:
      - domain
      - pkg
  pkg:
    mayDependOn: []
```

This config enforces:
- domain/ imports NOTHING from other layers
- app/ imports only domain/
- outbound/ imports only domain/
- inbound/ imports domain/ and pkg/ (for public types)
- pkg/ imports nothing internal

Run `go-arch-lint check` to verify. Zero false positives — violations are real bugs.

## CI Pipeline (.github/workflows/ci.yml)

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - run: go build ./...
      - run: go vet ./...
      - run: go test -race ./... -count=1 -v
        # testcontainers works in CI — Docker is available on ubuntu-latest
```

## Hooks Configuration

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "goimports -w $CLAUDE_FILE_PATH 2>/dev/null || true",
        "description": "Auto-format Go files after every edit"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "command": "go vet ./... && go build ./...",
        "description": "Verify build before every commit"
      }
    ]
  }
}
```

## Doc-Project Skeleton

Create this during bootstrap. go-finish will enrich it as features are built.

```
.claude/skills/doc-project/
├── SKILL.md              # Minimal TOC — first context only
├── conventions.md        # Patterns from bootstrap
└── contexts/             # Empty — populated by go-finish per feature
```

### SKILL.md (initial)

```markdown
---
name: doc-project
description: Project map for [project-name]. Read this before scanning the codebase.
  Provides bounded context inventory, entity relationships, infrastructure wiring,
  and conventions. Always check this first — it's faster than grep.
invoke: agent
trigger: description
---

# Project Map: [project-name]

## Bounded Contexts

| Context | Entities | Endpoints | Events | Doc |
|---------|----------|-----------|--------|-----|
| [first-context] | — | 1 HTTP (health) | — | [details](contexts/[first-context].md) |

## Infrastructure
- [list from bootstrap interview — e.g., "Postgres 17", "Redis 7", "NATS JetStream"]

## Conventions
- IDs: UUID v7, typed (`type XxxID string`) — [details](conventions.md)
- Errors: `domainerror.New(code, message)` — [details](conventions.md)
- Mocks: function-based with panic on unset — [details](conventions.md)
- Scoping: all repo methods take scopeID first after ctx — [details](conventions.md)

## Latest Migration: 001_initial.sql

## Recent Features
- Bootstrap completed [date]
```

### conventions.md (initial)

```markdown
# Conventions

Established during bootstrap. Updated by go-finish as features add new patterns.

## IDs
- All entity IDs use UUID v7: `type XxxID string`, `func NewXxxID() XxxID`
- Parameter order: broad to narrow — `(ctx, scopeID, entityID)`

## Errors
- Domain errors: `domainerror.New(code, message)` — `domain/errors/errors.go`
- HTTP error responses: `{"error": {"code": "...", "message": "..."}}` via `writeErrorJSON()`

## Mocks
- Function-based: `XxxFunc func(...)` fields on mock structs
- Unset functions panic: `"called not defined XxxFunc"`
- Compile-time check: `var _ Interface = (*Mock)(nil)`

## Testing
- All tests run with `-race` flag
- Testcontainers for infrastructure (Postgres, Redis, etc.)
- Contract tests shared between mock and real adapter

## Scoping
- All repository methods include scopeID as first param after ctx
- SQL queries always filter by both entity ID AND scope ID
```
