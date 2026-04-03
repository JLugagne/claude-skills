# Go Scaffolder — Patterns

Reference patterns for scaffold code generation. Each section is a self-contained template that agents read on demand.

---

## Unit of Work Interface

```go
// domain/uow/uow.go
//
// The UoW wraps multiple repository operations in a single transaction.
// The `Do` callback receives a context that carries the transaction —
// every repository obtained from `repos` uses that same transaction,
// so either all writes commit or all roll back.
type UnitOfWork interface {
    // Do executes fn inside a transaction. If fn returns an error the
    // transaction is rolled back; otherwise it commits.
    // The ctx passed to fn carries the transaction — pass it through
    // to every repository call so they join the same transaction.
    Do(ctx context.Context, fn func(ctx context.Context, repos Repositories) error) error
}

// Repositories is a factory for transaction-scoped repository instances.
// Add one method per repository the feature needs.
// Each method returns a repository that operates within the UoW transaction.
type Repositories interface {
    // One method per repository — returns the transactional version.
    // The returned repository MUST use the transaction from the UoW context,
    // not a standalone connection, or atomicity is lost.
    Xxx() xxx.XxxRepository
}
```

---

## Mock Unit of Work

```go
// domain/uow/uowtest/mock.go
//
// The mock UoW lets unit tests control transaction behavior without a real database.
// Tests set DoFunc to capture and inspect the callback, or to simulate errors.
type MockUnitOfWork struct {
    // DoFunc is set by each test to define transaction behavior.
    // A nil DoFunc panics on call — this catches tests that forget to wire it.
    DoFunc func(ctx context.Context, fn func(ctx context.Context, repos uow.Repositories) error) error
}

func (m *MockUnitOfWork) Do(ctx context.Context, fn func(ctx context.Context, repos uow.Repositories) error) error {
    if m.DoFunc == nil {
        // Panic instead of returning nil — a nil return silently succeeds,
        // hiding the fact that the test never configured transaction behavior.
        panic("called not defined DoFunc")
    }
    return m.DoFunc(ctx, fn)
}
```

---

## Repository Interface

```go
// internal/<context>/domain/repositories/<entity>/<entity>.go
//
// This is the outbound port. The domain and app layers depend on this
// interface, never on the concrete adapter. This is what makes it
// possible to swap Postgres for DynamoDB without touching business logic.
type XxxRepository interface {
    Create(ctx context.Context, projectID types.ProjectID, xxx domain.Xxx) error
    FindByID(ctx context.Context, projectID types.ProjectID, id types.XxxID) (*domain.Xxx, error)
    List(ctx context.Context, projectID types.ProjectID, ...) ([]domain.Xxx, error)
    Delete(ctx context.Context, projectID types.ProjectID, id types.XxxID) error
    // ALL methods MUST include projectID — this is the tenant isolation boundary.
    // Without it, a user could access another tenant's data (IDOR vulnerability).
    // Parameter order: broad to narrow — (projectID, entityID) — never reversed.
    // This convention keeps all repositories consistent across the codebase,
    // making code review easier and reducing the chance of parameter-swap bugs.
}
```

---

## Repository Mock and Contract

```go
// internal/<context>/domain/repositories/<entity>/<entity>test/contract.go
//
// This file serves two purposes:
// 1. MockXxxRepository — used by app-layer unit tests to isolate business logic.
// 2. XxxContractTesting — a shared contract suite run against BOTH the mock
//    and the real adapter, proving they behave identically.

type MockXxxRepository struct {
    // Each method gets its own func field so tests only wire the methods they
    // care about. Unwired methods panic — see below.
    CreateFunc   func(ctx context.Context, ...) error
    FindByIDFunc func(ctx context.Context, ...) (*domain.Xxx, error)
}

func (m *MockXxxRepository) Create(ctx context.Context, ...) error {
    if m.CreateFunc == nil {
        // Panic, don't return nil. A nil return means "success", which hides
        // the fact that the test forgot to configure this method.
        panic("called not defined CreateFunc")
    }
    return m.CreateFunc(ctx, ...)
}

// Compile-time check — if this line fails to compile, the mock is missing
// a method or has a wrong signature. Catches typos that would otherwise
// only surface as runtime wiring errors.
var _ <entity>.XxxRepository = (*MockXxxRepository)(nil)

// XxxContractTesting is the shared contract suite. Both the mock and the
// real Postgres adapter run this same function, so if the mock says
// "Create stores and FindByID retrieves" then the real adapter must too.
func XxxContractTesting(t *testing.T, repo <entity>.XxxRepository, ...) {
    t.Run("Contract: Create stores and FindByID retrieves", func(t *testing.T) {
        // t.Skip is removed by the QA agent when writing real assertions.
        // Leave it here — a passing stub gives false confidence.
        t.Skip("TODO: waiting for red")
    })
    // Add one t.Run per expected behavior, all with t.Skip().
    // The QA agent uses these names to understand what behaviors to test.
}
```

---

## Service Interface

```go
// internal/<context>/domain/services/<entity>/<entity>.go
//
// This is the inbound port. Handlers depend on this interface,
// never on *app.App directly. This allows testing handlers with a
// mock service and swapping app implementations without touching HTTP code.
type XxxService interface {
    Create(ctx context.Context, projectID types.ProjectID, name string) (*domain.Xxx, error)
    GetByID(ctx context.Context, projectID types.ProjectID, id types.XxxID) (*domain.Xxx, error)
    List(ctx context.Context, projectID types.ProjectID, ...) ([]domain.Xxx, error)
    Delete(ctx context.Context, projectID types.ProjectID, id types.XxxID) error
    // Same projectID-first convention as the repository interface.
    // Method names differ slightly (GetByID vs FindByID) to reflect the
    // service's richer semantics (authorization, validation, etc.).
}
```

---

## Service Mock and Contract

```go
// internal/<context>/domain/services/<entity>/<entity>test/contract.go
//
// Same dual-purpose pattern as the repository mock/contract:
// 1. MockXxxService — used by handler tests to isolate HTTP logic from business logic.
// 2. XxxServiceContractTesting — shared suite run against mock AND real app,
//    proving the app satisfies the same contract handlers expect.

type MockXxxService struct {
    // One func field per interface method.
    // Only wire the methods your test exercises — unwired ones panic.
    CreateFunc   func(ctx context.Context, ...) (*domain.Xxx, error)
    GetByIDFunc  func(ctx context.Context, ...) (*domain.Xxx, error)
}

func (m *MockXxxService) Create(ctx context.Context, ...) (*domain.Xxx, error) {
    if m.CreateFunc == nil {
        // Panic to surface unwired methods immediately.
        panic("called not defined CreateFunc")
    }
    return m.CreateFunc(ctx, ...)
}

// Compile-time check — same purpose as the repository one.
var _ <entity>.XxxService = (*MockXxxService)(nil)

// XxxServiceContractTesting runs against both mock and real app implementation.
// This ensures the mock used in handler tests behaves like the real app,
// so handler tests remain trustworthy even though they never hit the database.
func XxxServiceContractTesting(t *testing.T, svc <entity>.XxxService, ...) {
    t.Run("Contract: Create and GetByID", func(t *testing.T) {
        t.Skip("TODO: waiting for red")
    })
}
```

---

## Repository Implementation (Outbound Adapter)

```go
// internal/<context>/outbound/<adapter>/<adapter>_<entity>.go
//
// This is the concrete adapter — the only place that knows about the
// actual database. It implements the repository interface from domain/.

type xxxRepository struct {
    // Inject the database pool, client, or connection here.
    // Use the pool type that matches the adapter (e.g., *pgxpool.Pool for Postgres).
    // The field is unexported — only the constructor and methods access it.
}

// Compile-time check — ensures this adapter actually implements the interface.
// Without this, a renamed method silently creates a dead method and the
// wiring fails at runtime with a confusing "does not implement" error.
var _ <entity>.XxxRepository = (*xxxRepository)(nil)

func (r *xxxRepository) Create(ctx context.Context, ...) error {
    // Return nil (not an error) so the project compiles and tests skip cleanly.
    // Real implementation is written in the green phase.
    return nil // TODO: implement
}
```

---

## Repository Contract Test

```go
// internal/<context>/outbound/<adapter>/<entity>_contract_test.go
//
// This test runs the shared contract suite from <entity>test against a
// REAL database (via testcontainers). It proves the adapter behaves
// identically to the mock used in unit tests.

func TestXxxRepositoryContract(t *testing.T) {
    // Skip until the QA agent writes real assertions in the contract suite.
    // Running an empty contract against a real DB wastes CI time.
    t.Skip("TODO: waiting for red")
    // When unskipped, this will:
    // 1. Start a testcontainer (Postgres, Redis, etc.)
    // 2. Run migrations
    // 3. Call <entity>test.XxxContractTesting(t, realRepo, ...)
}
```

---

## App Service Implementation

```go
// internal/<context>/app/<entity>.go
//
// The App struct implements the service interface from domain/services/.
// It holds repository interfaces (never concrete adapters) as dependencies.

// Compile-time check — if the App is missing a method or has a wrong
// signature, this fails at compile time instead of at runtime during wiring.
var _ <entity>.XxxService = (*App)(nil)

func (a *App) CreateXxx(ctx context.Context, ...) (*domain.Xxx, error) {
    // Return zero values so the project compiles cleanly.
    // Real business logic (validation, repo calls, event emission) is
    // written in the green phase after tests are red.
    return nil, nil // TODO: implement
}
```

---

## App Contract Test

```go
// internal/<context>/app/<entity>_contract_test.go
//
// Contract tests verify the app service works correctly with REAL repositories
// (via testcontainers). This tests the full app -> repo -> db flow without HTTP.
// It catches integration bugs that unit tests (with mocks) cannot.

func TestAppXxxContract(t *testing.T) {
    // Skip until the QA agent writes real assertions.
    t.Skip("TODO: waiting for red")
    // When unskipped, this will:
    // 1. Start testcontainers for all required infrastructure
    // 2. Create real repository adapters pointing at the containers
    // 3. Build a real App with those repositories
    // 4. Call <entity>test.XxxServiceContractTesting(t, realApp, ...)
}
```

---

## HTTP Types (pkg layer)

```go
// pkg/<context>/<entity>.go
//
// These are the PUBLIC API types — they define the JSON contract with clients.
// They live in pkg/ because other services and clients import them.
// NEVER embed domain types here; map every field explicitly via converters.

type CreateXxxRequest struct {
    // Each field gets a json tag. Use snake_case for JSON (Go convention for APIs).
    // Validation tags (if using a validator) go here too.
    Type    string `json:"type"`
    Message string `json:"message"`
}

type XxxResponse struct {
    // Mirror the API contract exactly. If a field is removed from the domain
    // model, this struct stays unchanged until the API version is bumped.
    ID        string `json:"id"`
    ProjectID string `json:"project_id"`
    Type      string `json:"type"`
    Message   string `json:"message"`
    Read      bool   `json:"read"`
    CreatedAt string `json:"created_at"`
}
```

---

## Event Types

```go
// pkg/<context>/events/consumed.go — events this context receives from other services.
// These are public contracts: other teams publish these, so changing fields is a
// breaking change that requires coordination.
type ProjectCreatedEvent struct {
    ProjectID string `json:"project_id"`
    Name      string `json:"name"`
    Timestamp string `json:"timestamp"`
    // Use string for IDs and timestamps in events (not typed IDs or time.Time).
    // Events cross service boundaries — typed IDs are internal to each service.
}

// pkg/<context>/events/emitted.go — events this context publishes for others to consume.
// Other services depend on this schema. Add fields carefully; removing fields
// is a breaking change.
type NotificationSentEvent struct {
    NotificationID string `json:"notification_id"`
    ProjectID      string `json:"project_id"`
    Type           string `json:"type"`
    Timestamp      string `json:"timestamp"`
}
```

---

## gRPC Scaffold (if feature has gRPC endpoints)

Create:
- `pkg/<context>/grpc/proto/<context>.proto` — proto definitions from API design
- Run `protoc` to generate `<context>.pb.go` and `<context>_grpc.pb.go`
- `internal/<context>/inbound/grpc/<entity>_handler.go` — handler stub
- `internal/<context>/inbound/grpc/converters/<entity>.go` — converter stubs
- Compile-time check: `var _ pb.XxxServiceServer = (*XxxGRPCHandler)(nil)`

Proto file conventions:
- Package name: `<context>` (e.g., `package scan;`)
- Service name: `<Entity>Service` (e.g., `service ScanService`)
- Message names: `<Verb><Entity>Request/Response` (e.g., `CreateScanRequest`)
- Field numbers are stable — never reuse or renumber

```go
// internal/<context>/inbound/grpc/<entity>_handler.go
type XxxGRPCHandler struct {
    pb.Unimplemented<Entity>ServiceServer
    svc <entity>.XxxService  // service INTERFACE from domain/services/, NOT *app.App
}

func NewXxxGRPCHandler(svc <entity>.XxxService) *XxxGRPCHandler {
    return &XxxGRPCHandler{svc: svc}
}

// Compile-time check — ensures handler implements the gRPC server interface.
var _ pb.XxxServiceServer = (*XxxGRPCHandler)(nil)

func (h *XxxGRPCHandler) CreateXxx(ctx context.Context, req *pb.CreateXxxRequest) (*pb.CreateXxxResponse, error) {
    return nil, status.Errorf(codes.Unimplemented, "not implemented") // TODO: implement
}
```

```go
// internal/<context>/inbound/grpc/converters/<entity>.go
// Converters translate between proto types (pkg/<context>/grpc/) and domain types.
// Same pattern as HTTP converters — explicit field mapping, no reflection.

func ToDomainXxx(req *pb.CreateXxxRequest, scopeID types.ScopeID) domain.Xxx {
    return domain.Xxx{} // TODO: implement
}

func ToProtoXxx(x domain.Xxx) *pb.XxxResponse {
    return &pb.XxxResponse{} // TODO: implement
}
```

---

## Inbound Handler Stub

```go
// internal/<context>/inbound/<protocol>/<entity>_handler.go
//
// Handlers depend on the SERVICE INTERFACE from domain/services/, NOT on *app.App.
// This is the key architectural boundary: if you import app/ here, you've
// coupled the transport layer to the business logic and broken the hexagon.

type XxxHandler struct {
    // The field type is the interface, not the concrete app.
    // This allows handler tests to inject a MockXxxService.
    svc <entity>.XxxService  // service INTERFACE from domain/services/, NOT *app.App
}

// NewXxxHandler is the constructor. It takes the interface, not the concrete type.
// The wiring layer (init.go) passes *app.App here, which satisfies the interface.
func NewXxxHandler(svc <entity>.XxxService) *XxxHandler {
    return &XxxHandler{svc: svc}
}
```

---

## Inbound Converter

```go
// internal/<context>/inbound/<protocol>/converters/<entity>.go
//
// Converters translate between public API types (pkg/) and domain types (domain/).
// They are the ONLY place where this translation happens — handlers and services
// never do raw field copying.

// ToDomainXxx converts an incoming API request into a domain object.
// This is where you apply default values, normalize strings, etc.
func ToDomainXxx(req pkgcontext.CreateXxxRequest, projectID types.ProjectID) domain.Xxx {
    // Map every field explicitly. Never use struct embedding or reflection.
    // Explicit mapping means a new API field won't accidentally leak into the domain.
    return domain.Xxx{} // TODO: implement
}

// ToPublicXxx converts a domain object into an API response.
// Domain fields that are internal (e.g., internal counters) are omitted here.
func ToPublicXxx(x domain.Xxx) pkgcontext.XxxResponse {
    // Map every field explicitly. If a domain field is renamed, this is the
    // only place that needs to change — the API response stays stable.
    return pkgcontext.XxxResponse{} // TODO: implement
}

// ToPublicXxxList converts a slice. Use a generic MapSlice helper if available.
func ToPublicXxxList(items []domain.Xxx) []pkgcontext.XxxResponse {
    return MapSlice(items, ToPublicXxx)
}
```

---

## Converter Test

```go
// internal/<context>/inbound/<protocol>/converters/<entity>_test.go
//
// Converter tests verify that every field is mapped correctly in both directions.
// These are simple, fast, and catch the most common bug: a new field that was
// added to the domain but not wired into the API response (or vice versa).

func TestToPublicXxx(t *testing.T) {
    // Test that domain -> public maps all fields correctly.
    // The QA agent will fill in field-by-field assertions.
    t.Skip("TODO: waiting for red")
}

func TestToDomainXxx(t *testing.T) {
    // Test that public request -> domain maps all fields correctly.
    t.Skip("TODO: waiting for red")
}
```

---

## Wiring (init.go)

```go
// internal/<context>/init.go
//
// Setup() is the composition root — the ONE place that knows about all concrete types.
// main.go calls Setup() and starts the server; it never imports adapters directly.
// This keeps main.go trivial and makes the dependency graph easy to audit.

func Setup(pool *pgxpool.Pool) (*http.ServeMux, error) {
    // 1. Outbound adapters — concrete implementations of repository interfaces.
    //    These are the only lines that import the adapter packages.
    xxxRepo := pg.NewXxxRepository(pool)

    // 2. App service — implements the service interface from domain/services/.
    //    It receives repository INTERFACES, not concrete adapters.
    xxxApp := app.New(xxxRepo)

    // 3. Inbound handlers — receive the service INTERFACE, not *app.App.
    //    xxxApp satisfies XxxService because of the compile-time check in app/.
    xxxHandler := http.NewXxxHandler(xxxApp)

    // 4. Register routes — connect HTTP paths to handler methods.
    // ...
}
```

---

## E2E Test Setup

```go
// tests/e2e-api/setup_test.go
//
// TestMain is the entry point for all e2e tests in this package.
// It starts real infrastructure (Postgres, Redis, etc.) via testcontainers,
// runs migrations, seeds data, and starts the HTTP server.
// All e2e tests in this package share this setup — they hit a real server.

package e2e_api

func TestMain(m *testing.M) {
    // When unskipped, this will:
    // 1. Start a PostgreSQL testcontainer
    // 2. Run all migrations
    // 3. Seed any required reference data
    // 4. Start the HTTP server on a random port
    // 5. Run all tests via m.Run()
    // 6. Tear down containers

    // t.Skip("TODO: waiting for e2e red")
}
```
