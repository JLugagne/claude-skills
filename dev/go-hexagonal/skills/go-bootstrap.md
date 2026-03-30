---
type: skill
name: go-bootstrap
description: Bootstraps a new Go project from scratch with hexagonal architecture, testcontainers, CI pipeline, and the full skill/agent suite installed. Use when starting a new project or microservice.
model: opus
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

### Project Structure
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

### Foundation Code

#### Domain Error Pattern
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

#### Typed ID Pattern
```go
type ProjectID string

func NewProjectID() ProjectID {
    return ProjectID(uuid.New().String())
}
```

#### Service Interface Pattern (Inbound Ports)

Service interfaces live in `domain/services/` — they are the driving ports that inbound adapters depend on. The app layer implements them.

```go
// internal/<context>/domain/services/project/project.go
package project

type ProjectService interface {
    // Methods defined when features are added
}
```

```go
// internal/<context>/domain/services/project/projecttest/contract.go
package projecttest

// Mock + contract tests added when features are added
```

This is symmetric with repository interfaces in `domain/repositories/` (driven ports). Inbound handlers depend on service interfaces, never on `*app.App` directly.

#### Repository Interface Pattern (Outbound Ports)

```go
// internal/<context>/domain/repositories/project/project.go
package project

type ProjectRepository interface {
    // Methods defined when features are added
}
```

#### Event Types Pattern

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

#### init.go — Dependency Injection & Wiring

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

#### Structured Logging Setup

Bootstrap the project with a structured logger from the start. Follow the user's choice (slog, zap, zerolog) or default to `log/slog`:

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

Every service method logs with structured fields (entity IDs, scope IDs, operation name). See go-dev Observability Standards for the full pattern.

#### Structured Error Response
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

#### Health Check
```go
func (h *Handlers) HealthCheck(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
```

#### E2E Test Setup (testcontainers)
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

#### Makefile
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

migrate:
	# Run migrations against local dev database
```

#### docker-compose.yml
Generate with the appropriate services for the user's chosen infrastructure (postgres, redis, rabbitmq, etc.) with health checks and volume mounts.

#### CI Pipeline (.github/workflows/ci.yml)
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

### Install Skill/Agent Suite

Copy all 12 agent files to `.claude/agents/`:
- `go-pm.md` — Product manager (spec interrogation, aggregate identification)
- `go-architect.md` — Architecture design (TASKS.md generation)
- `go-api-designer.md` — HTTP API design (routes, types, validation)
- `go-scaffolder.md` — Scaffolding (stubs, interfaces, mocks, skipped tests)
- `go-test-writer.md` — Red phase TDD (failing tests)
- `go-dev.md` — Green phase TDD (implementation + observability)
- `go-reviewer.md` — Review (architecture, security, data, performance, compatibility)
- `go-migrator.md` — Data migrations (backfill, transform, split)
- `go-fixer.md` — Circuit breaker recovery (fresh-perspective fixes)
- `go-runner.md` — Task execution (dispatch, validate, report)
- `go-refactor.md` — Safe refactoring (document, lock, rewrite)
- `go-bootstrap.md` — This file

## Verification

After bootstrapping:
1. `go build ./...` — passes
2. `go test -race ./... -short` — health check test passes
3. `docker-compose up -d` — infrastructure starts
4. `curl localhost:<port>/health` — returns `{"status":"ok"}`
5. `.claude/agents/` has 12 agent files
6. `domain/services/` directory exists (inbound port interfaces)
7. `domain/repositories/` directory exists (outbound port interfaces)
8. `pkg/<context>/events/` directory exists (event contracts)

## After Bootstrap

Tell the user: "Project is ready. Describe your first feature and I'll plan and implement it using the full skill pipeline."

The go-pm skill takes over from here for feature development.
