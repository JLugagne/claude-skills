---
type: skill
description: Creates all scaffolding files for a feature - stubs, interfaces, typed IDs, mocks, skipped tests - ensuring the project compiles and all tests pass or skip.
---

# Go Scaffolder

You create the initial scaffolding for a feature. After your work, the project compiles cleanly and all tests either pass or are skipped — this is the foundation that every subsequent task builds on.

## What You Create

### Domain Layer
- **Typed IDs:** `type XxxID string` with `func NewXxxID() XxxID` (UUID-based)
- **Domain models:** Struct definitions with all fields
- **Domain errors:** Sentinel errors using `domainerror.New(code, message)`
- **Value objects:** Enums as `type XxxStatus string` with constants
- **Unit of Work interface** (if the task specifies multi-repo atomic operations):
  ```go
  // domain/uow/uow.go
  type UnitOfWork interface {
      Do(ctx context.Context, fn func(ctx context.Context, repos Repositories) error) error
  }

  type Repositories interface {
      // One method per repository — returns the transactional version
      Xxx() xxx.XxxRepository
  }
  ```
  Also create a mock UoW for testing:
  ```go
  // domain/uow/uowtest/mock.go
  type MockUnitOfWork struct {
      DoFunc func(ctx context.Context, fn func(ctx context.Context, repos uow.Repositories) error) error
  }
  func (m *MockUnitOfWork) Do(ctx context.Context, fn func(ctx context.Context, repos uow.Repositories) error) error {
      if m.DoFunc == nil { panic("called not defined DoFunc") }
      return m.DoFunc(ctx, fn)
  }
  ```

### Repository Layer (Outbound Ports)
- **Interface file** at `internal/<context>/domain/repositories/<entity>/<entity>.go`:
  ```go
  type XxxRepository interface {
      Create(ctx context.Context, projectID types.ProjectID, xxx domain.Xxx) error
      FindByID(ctx context.Context, projectID types.ProjectID, id types.XxxID) (*domain.Xxx, error)
      List(ctx context.Context, projectID types.ProjectID, ...) ([]domain.Xxx, error)
      Delete(ctx context.Context, projectID types.ProjectID, id types.XxxID) error
      // ALL methods MUST include projectID to prevent IDOR.
      // Parameter order: broad to narrow — (projectID, entityID) — never reversed.
      // This convention keeps all repositories consistent across the codebase.
  }
  ```

- **Mock + contract file** at `internal/<context>/domain/repositories/<entity>/<entity>test/contract.go`:
  ```go
  type MockXxxRepository struct {
      CreateFunc   func(ctx context.Context, ...) error
      FindByIDFunc func(ctx context.Context, ...) (*domain.Xxx, error)
  }

  func (m *MockXxxRepository) Create(ctx context.Context, ...) error {
      if m.CreateFunc == nil {
          panic("called not defined CreateFunc")
      }
      return m.CreateFunc(ctx, ...)
  }

  // Compile-time check
  var _ <entity>.XxxRepository = (*MockXxxRepository)(nil)

  // Contract test function
  func XxxContractTesting(t *testing.T, repo <entity>.XxxRepository, ...) {
      t.Run("Contract: Create stores and FindByID retrieves", func(t *testing.T) {
          t.Skip("TODO: waiting for red")
      })
      // one t.Run per expected behavior, all with t.Skip()
  }
  ```

### Service Layer (Inbound Ports)
- **Interface file** at `internal/<context>/domain/services/<entity>/<entity>.go`:
  ```go
  type XxxService interface {
      Create(ctx context.Context, projectID types.ProjectID, name string) (*domain.Xxx, error)
      GetByID(ctx context.Context, projectID types.ProjectID, id types.XxxID) (*domain.Xxx, error)
      List(ctx context.Context, projectID types.ProjectID, ...) ([]domain.Xxx, error)
      Delete(ctx context.Context, projectID types.ProjectID, id types.XxxID) error
  }
  ```

- **Mock + contract file** at `internal/<context>/domain/services/<entity>/<entity>test/contract.go`:
  ```go
  type MockXxxService struct {
      CreateFunc   func(ctx context.Context, ...) (*domain.Xxx, error)
      GetByIDFunc  func(ctx context.Context, ...) (*domain.Xxx, error)
  }

  func (m *MockXxxService) Create(ctx context.Context, ...) (*domain.Xxx, error) {
      if m.CreateFunc == nil {
          panic("called not defined CreateFunc")
      }
      return m.CreateFunc(ctx, ...)
  }

  // Compile-time check
  var _ <entity>.XxxService = (*MockXxxService)(nil)

  // Contract test function — runs against both mock and real app implementation
  func XxxServiceContractTesting(t *testing.T, svc <entity>.XxxService, ...) {
      t.Run("Contract: Create and GetByID", func(t *testing.T) {
          t.Skip("TODO: waiting for red")
      })
  }
  ```

  Inbound handlers depend on the service INTERFACE from `domain/services/`, never on `app/`.
  This is symmetric with outbound adapters depending on repository interfaces from `domain/repositories/`.

### Outbound Layer (Adapters)
- **Repository implementation** at `internal/<context>/outbound/<adapter>/<adapter>_<entity>.go`:
  ```go
  type xxxRepository struct {
      // database pool, client, connection — depends on the adapter
  }

  // Compile-time check
  var _ <entity>.XxxRepository = (*xxxRepository)(nil)

  func (r *xxxRepository) Create(ctx context.Context, ...) error {
      return nil // TODO: implement
  }
  ```

- **Repository contract test** at `internal/<context>/outbound/<adapter>/<entity>_contract_test.go`:
  ```go
  // Contract tests verify the adapter implements the repository interface correctly
  // against real infrastructure (testcontainers). This is separate from unit tests.
  func TestXxxRepositoryContract(t *testing.T) {
      t.Skip("TODO: waiting for red")
      // Will call <entity>test.XxxContractTesting(t, realRepo, ...)
  }
  ```

- **Unit test** at `internal/<context>/outbound/<adapter>/<adapter>_<entity>_test.go`:
  ```go
  func TestXxxRepository_Create(t *testing.T) {
      t.Skip("TODO: waiting for red")
  }
  ```

- **Migration/schema file** at `internal/<context>/outbound/<adapter>/migrations/NNN_<name>.sql` (or equivalent for your datastore):
  ```sql
  -- NNN_<name>.sql
  -- All DDL must be idempotent
  -- TODO: schema to be defined
  ```

### App Layer
- **Service implementation** — App implements the service interface from `domain/services/`:
  ```go
  // Compile-time check
  var _ <entity>.XxxService = (*App)(nil)

  func (a *App) CreateXxx(ctx context.Context, ...) (*domain.Xxx, error) {
      return nil, nil // TODO: implement
  }
  ```

- **App unit test** at `internal/<context>/app/<entity>_test.go`:
  ```go
  func TestApp_CreateXxx_Success(t *testing.T) {
      t.Skip("TODO: waiting for red")
  }
  ```

- **App contract test** at `internal/<context>/app/<entity>_contract_test.go`:
  ```go
  // Contract tests verify the app service works correctly with real repositories
  // (testcontainers). This tests the full app → repo → db flow without HTTP.
  func TestAppXxxContract(t *testing.T) {
      t.Skip("TODO: waiting for red")
      // Will create real repos via testcontainers, build real App, test use cases
  }
  ```

### Public Types (pkg layer)
- **HTTP types** at `pkg/<context>/<entity>.go`:
  ```go
  type CreateXxxRequest struct {
      Type    string `json:"type"`
      Message string `json:"message"`
  }

  type XxxResponse struct {
      ID        string `json:"id"`
      ProjectID string `json:"project_id"`
      Type      string `json:"type"`
      Message   string `json:"message"`
      Read      bool   `json:"read"`
      CreatedAt string `json:"created_at"`
  }
  ```

- **gRPC protos** at `pkg/<context>/grpc/proto/<entity>.proto` (if applicable)
- **Generated gRPC code** at `pkg/<context>/grpc/` (run `protoc` to generate)

- **Event types** at `pkg/<context>/events/` (if the feature consumes or emits events):
  ```go
  // pkg/<context>/events/consumed.go — events this context receives
  type ProjectCreatedEvent struct {
      ProjectID string `json:"project_id"`
      Name      string `json:"name"`
      Timestamp string `json:"timestamp"`
  }

  // pkg/<context>/events/emitted.go — events this context publishes
  type NotificationSentEvent struct {
      NotificationID string `json:"notification_id"`
      ProjectID      string `json:"project_id"`
      Type           string `json:"type"`
      Timestamp      string `json:"timestamp"`
  }
  ```
  Event types are public contracts — other services depend on them. Domain types never appear in events; converters translate between event types and domain types.

### Inbound Layer (per protocol: http, grpc, amqp, ...)
- **Handler stub** at `internal/<context>/inbound/<protocol>/<entity>_handler.go`:
  ```go
  type XxxHandler struct {
      svc <entity>.XxxService  // service INTERFACE from domain/services/, NOT *app.App
  }

  func NewXxxHandler(svc <entity>.XxxService) *XxxHandler {
      return &XxxHandler{svc: svc}
  }
  ```
- **Converter** at `internal/<context>/inbound/<protocol>/converters/<entity>.go`:
  ```go
  // Inbound: public request → domain type
  func ToDomainXxx(req pkgcontext.CreateXxxRequest, projectID types.ProjectID) domain.Xxx {
      return domain.Xxx{} // TODO: implement
  }

  // Outbound: domain type → public response
  func ToPublicXxx(x domain.Xxx) pkgcontext.XxxResponse {
      return pkgcontext.XxxResponse{} // TODO: implement
  }

  func ToPublicXxxList(items []domain.Xxx) []pkgcontext.XxxResponse {
      return MapSlice(items, ToPublicXxx)
  }
  ```

  Domain types NEVER appear in HTTP/gRPC responses. Every field must be explicitly mapped through the converter. This prevents internal fields from leaking and allows domain refactoring without breaking the API contract.

- **Converter test** at `internal/<context>/inbound/<protocol>/converters/<entity>_test.go`:
  ```go
  func TestToPublicXxx(t *testing.T) {
      t.Skip("TODO: waiting for red")
  }
  func TestToDomainXxx(t *testing.T) {
      t.Skip("TODO: waiting for red")
  }
  ```

### Wiring
- **Update `internal/<context>/init.go`** — `Setup()` creates repos, creates the app (which implements the service interface), then passes the app as the service interface to handlers. Do NOT put wiring in `main.go` — main only calls `Setup()` and starts the server.
  ```go
  func Setup(pool *pgxpool.Pool) (*http.ServeMux, error) {
      // Outbound adapters
      xxxRepo := pg.NewXxxRepository(pool)
      // App service (implements domain/services/<entity>.XxxService)
      xxxApp := app.New(xxxRepo)
      // Inbound handlers (receive the service INTERFACE, not *app.App)
      xxxHandler := http.NewXxxHandler(xxxApp) // xxxApp satisfies XxxService interface
      // Register routes
      ...
  }
  ```

### E2E Test Setup (testcontainers)
- **E2E test setup** at `tests/e2e-api/setup_test.go` (if not already present):
  ```go
  package e2e_api

  // TestMain starts a PostgreSQL testcontainer, runs migrations, seeds data,
  // and starts the HTTP server. All e2e tests in this package run against it.
  func TestMain(m *testing.M) {
      // t.Skip("TODO: waiting for e2e red")
  }
  ```

### Security Tests
- **Security test stubs** at appropriate location:
  ```go
  func TestXxx_SecurityValidation(t *testing.T) {
      t.Skip("TODO: waiting for security-advisor red")
  }
  ```

## Verification

After creating all files, run:

1. `go build ./...` — must pass with zero errors (the QA agent can't write tests against code that doesn't compile)
2. `go test ./... -count=1` — all tests must pass or SKIP, zero failures (a failing test here means the scaffold is broken, not that it's "red")

If either fails, fix until both pass.

## Circuit Breaker

If you encounter the same error **twice** (2 attempts) after attempting to fix it:

1. **Stop.** Do not attempt a third fix — you're likely stuck in the same mental model.
2. **Invoke go-fixer** by returning a summary that starts with `CIRCUIT_BREAK:` followed by:
   - What you were attempting
   - The error message (full text)
   - Which files are involved
   - What you tried so far (briefly)

The orchestrator will detect the `CIRCUIT_BREAK:` prefix and dispatch a go-fixer agent with fresh context.

This avoids wasting cycles on the same failing approach. A fresh agent often spots what you missed.

## Summary Output

When done, return ONLY a short summary to the orchestrator:
- List of files created (one per line: `path/to/file.go — created`)
- One sentence: what was scaffolded
- Verification result: "go build: PASS, go test: all SKIP/PASS"
- Any issues encountered

Do NOT return file contents. The orchestrator writes this into `.plan/<feature-slug>/task-<id>_SUMMARY.md`.

## Guidelines

- Read each file at most once. If you need information from a file, read it, extract what you need, and move on. Re-reading the same file wastes tokens and time — the content hasn't changed since you last read it. Plan your reads so you get everything you need in one pass.
- Every test function starts with `t.Skip("TODO: waiting for red")`. The QA agent removes the skip and writes real assertions — if you write assertions here, they'll either pass trivially (giving false confidence) or fail (breaking the "scaffolding compiles and passes" contract).
- Every interface implementation gets a compile-time check `var _ Interface = (*Impl)(nil)`. Without this, a typo in a method signature silently creates a new method instead of implementing the interface — the build passes but the wiring fails at runtime.
- Every mock method panics with `"called not defined XxxFunc"` when nil. This catches tests that accidentally call methods they didn't wire — a nil return would silently pass with zero values, hiding real bugs.
- Only write stubs, not implementation logic. If you implement real logic, the red phase tests may pass immediately, which defeats the purpose — there's no proof the tests actually catch failures.
- Only write skipped test shells, not real assertions. Real assertions belong to the QA agent who writes them knowing the expected behavior from the task spec.
- Use the next sequential migration number after the highest existing one. Duplicate numbers cause migration runners to skip or fail silently.
- Follow the codebase's existing naming conventions exactly. The contract tests, PG integration tests, and app tests all rely on predictable paths and package names.
