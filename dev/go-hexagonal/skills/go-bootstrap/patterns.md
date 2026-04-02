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

migrate:
	# Run migrations against local dev database
```

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
