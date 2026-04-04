# Go Developer — Implementation Patterns

Reference patterns for the green-phase developer. Each section is a self-contained example you can adapt to the feature you are implementing.

---

## Domain Layer

```go
// Typed IDs — every aggregate root gets its own ID type.
// This prevents passing a UserID where a ProjectID is expected;
// the compiler catches the mistake instead of a runtime bug.
type XxxID string

// NewXxxID generates a fresh unique identifier.
// Always use this constructor — never assign raw strings — so every ID
// in the system is guaranteed to be a valid UUID.
func NewXxxID() XxxID {
    return XxxID(uuid.New().String())
}

// Domain errors — define ALL business-rule violations as package-level
// sentinel errors using domainerror.New.  The first arg is a machine-readable
// code (used by inbound adapters to map to HTTP/gRPC status codes); the second
// is a human-readable message.
// Group related errors in a single var block so they are easy to discover.
var (
    ErrXxxNotFound       = domainerror.New("XXX_NOT_FOUND", "xxx not found")
    ErrXxxNameRequired   = domainerror.New("XXX_NAME_REQUIRED", "xxx name is required")
)
```

---

## Outbound Layer — Repository Adapter

```go
// Example with SQL (adapt to your driver: pgx, sqlx, gorm, mongo, redis, etc.)
//
// KEY RULES:
//   1. Every query on a scope-scoped entity MUST include the scope ID
//      (e.g., project_id) in the WHERE clause to prevent IDOR.
//   2. Only map the driver's specific "not found" sentinel to the domain
//      error. All other errors (timeout, connection, constraint violation)
//      must propagate unwrapped so callers can distinguish transient from
//      permanent failures.
func (r *xxxRepository) FindByID(ctx context.Context, projectID domain.ProjectID, id domain.XxxID) (*domain.Xxx, error) {
    // Always pass ctx so the query respects request-scoped deadlines and
    // tracing spans.
    row := r.db.QueryRow(ctx,
        // CRITICAL: the AND project_id = $2 clause is the IDOR guard.
        // Removing it means any caller who knows (or guesses) the entity ID
        // can read data belonging to another project.
        `SELECT id, name, created_at FROM xxx WHERE id = $1 AND project_id = $2`,
        string(id), string(projectID),  // Convert typed IDs to strings for the driver.
    )

    var item domain.Xxx
    err := row.Scan(&item.ID, &item.Name, &item.CreatedAt)

    // Map ONLY the driver's "no rows" sentinel to the domain not-found error.
    // This is the ONLY place where a driver-specific import is acceptable in
    // the outbound adapter.  Driver examples:
    //   pgx:   errors.Is(err, pgx.ErrNoRows)
    //   sql:   errors.Is(err, sql.ErrNoRows)
    //   mongo: errors.Is(err, mongo.ErrNoDocuments)
    //   redis: errors.Is(err, redis.Nil)
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, domain.ErrXxxNotFound
    }

    // All other errors propagate with a context prefix so stack traces
    // are readable. Use the pattern "verb noun: %w".
    if err != nil {
        return nil, fmt.Errorf("find xxx by id: %w", err)
    }

    return &item, nil
}
```

---

## App Layer — Service Method

```go
func (a *App) CreateXxx(ctx context.Context, projectID domain.ProjectID, name string) (*domain.Xxx, error) {
    // 1. Validate — check business rules BEFORE constructing the domain model.
    //    Return domain errors immediately so the caller gets a clear signal
    //    without any side effects having occurred.
    if strings.TrimSpace(name) == "" {
        return nil, domain.ErrXxxNameRequired
    }

    // 2. Construct the domain model — this is the single source of truth
    //    for the entity's initial state. Use typed IDs and time.Now() for
    //    timestamps (the test clock can be injected if needed).
    item := domain.Xxx{
        ID:        domain.NewXxxID(),
        Name:      strings.TrimSpace(name),  // Always sanitize before storing.
        CreatedAt: time.Now(),
    }

    // 3. Persist — delegate to the repository interface (domain layer).
    //    The outbound adapter handles driver-specific details.
    //    Wrap errors with "verb noun: %w" for consistent error chains.
    if err := a.xxxRepo.Create(ctx, projectID, item); err != nil {
        return nil, fmt.Errorf("create xxx: %w", err)
    }

    // 4. Log — structured logging with the entity ID so ops can correlate
    //    log lines to specific entities during incident response.
    a.logger.WithField("id", item.ID).Info("created xxx")

    return &item, nil
}
```

---

## Unit of Work — Multi-Repo Atomic Operations

Use UoW ONLY when the task requires atomic writes across multiple repositories. Single-repo operations should call the repo directly.

```go
// --- App service using UoW ---
// The service calls uow.Do and receives a Repositories bag scoped to the
// transaction.  All repo calls inside the closure share the same tx, so
// either everything commits or everything rolls back.
func (a *App) TransferOwnership(ctx context.Context, projectID, newOwnerID types.ID) error {
    return a.uow.Do(ctx, func(ctx context.Context, repos uow.Repositories) error {
        // Read inside the transaction to get a consistent snapshot.
        project, err := repos.Projects().FindByID(ctx, projectID)
        if err != nil { return err }

        // Mutate the domain model — keep business logic here, not in the repo.
        project.OwnerID = newOwnerID

        // Write back through the transactional repo.
        if err := repos.Projects().Update(ctx, project); err != nil { return err }

        // Second repo call — still inside the same tx.
        return repos.Notifications().Create(ctx, projectID, domain.Notification{
            Type:    domain.NotificationTypeOwnerChanged,
            Message: "Ownership transferred",
        })
    })
}

// --- Outbound UoW implementation (example with SQL) ---
// This is the adapter that turns uow.UnitOfWork into real database
// transactions.  Swap pgxpool for your driver's connection type.
type unitOfWork struct {
    pool *pgxpool.Pool
}

func (u *unitOfWork) Do(ctx context.Context, fn func(ctx context.Context, repos uow.Repositories) error) error {
    // Begin a database transaction.
    tx, err := u.pool.Begin(ctx)
    if err != nil { return fmt.Errorf("begin tx: %w", err) }

    // defer Rollback is safe — it's a no-op after a successful Commit.
    defer tx.Rollback(ctx)

    // Build repository implementations that use the tx instead of the pool.
    // This is what makes all repo calls share the same transaction.
    txRepos := &txRepositories{tx: tx}

    if err := fn(ctx, txRepos); err != nil { return err }

    // Commit only if the closure succeeded without error.
    return tx.Commit(ctx)
}
```

---

## Wiring (init.go)

When your green task creates new repositories or services, update `internal/<context>/init.go`:

```go
// internal/<context>/init.go
//
// This is the composition root. The ONLY place that imports outbound adapter packages.
// main.go calls Setup() and starts the server — it never imports adapters directly.

func Setup(pool *pgxpool.Pool) (*Server, error) {
    // 1. Outbound adapters — concrete implementations of repository interfaces.
    xxxRepo := pg.NewXxxRepository(pool)

    // 2. App service — implements the service interface from domain/services/.
    //    Receives repository INTERFACES, not concrete adapters.
    xxxApp := app.New(xxxRepo)

    // 3. Inbound handlers — receive the service INTERFACE, not *app.App.
    //    xxxApp satisfies XxxService because of the compile-time check in app/.
    xxxHandler := http.NewXxxHandler(xxxApp)

    // 4. Register routes — connect HTTP paths to handler methods.
    xxxHandler.RegisterRoutes(r)
}
```

**Rules:**
- NEVER put wiring in `cmd/` or `main.go` — init.go is the single composition root.
- Handlers receive the service **interface** from `domain/services/`, not `*app.App`.
- If init.go isn't updated, the feature compiles and tests pass (locally mocked) but the feature won't be accessible from endpoints.

---

## Inbound Layer — Converters

```go
// ToPublicXxx converts a domain model to an API response DTO.
// This layer exists so the domain model is never leaked to the wire format.
// If a field is renamed or removed in the API, only this converter changes.
//
// Rules:
//   - Typed IDs → string: always convert with string(item.ID).
//   - Timestamps → string: always format with time.RFC3339 for consistency.
//   - Never expose internal fields (e.g., internal state machines, soft-delete
//     flags) — only map what the API contract specifies.
func ToPublicXxx(item domain.Xxx) pkgserver.XxxResponse {
    return pkgserver.XxxResponse{
        ID:        string(item.ID),
        Name:      item.Name,
        CreatedAt: item.CreatedAt.Format(time.RFC3339),
    }
}
```

---

## E2E Test Wiring

When the task is a green phase for e2e tests, you wire up real infrastructure (not mocks). The red-phase test file already has `TestMain` with testcontainer setup and seeding — you implement `setupServer(...)` and `runMigrations(...)`.

```go
// setupServer wires the real server using the test infrastructure.
// Adapt the db parameter type to your driver:
//   pgxpool.Pool, *mongo.Database, *redis.Client, etc.
//
// This is NOT a mock — it uses real repository implementations so the e2e
// test exercises the full stack: HTTP handler → app service → repo → database.
func setupServer(db interface{}) *httptest.Server {
    repo := outbound.NewXxxRepository(db)    // Real repo backed by testcontainer DB.
    appService := app.New(repo)              // App service with real dependencies.
    handler := handlers.NewXxxHandler(appService)  // HTTP handler layer.

    r := mux.NewRouter()
    handler.RegisterRoutes(r)  // Register all routes on the shared router.

    // httptest.NewServer starts a real HTTP server on a random port.
    // The test makes real HTTP calls against this server.
    return httptest.NewServer(r)
}

// runMigrations applies database schema before tests run.
// Adapt to your migration tool: golang-migrate, goose, atlas, etc.
// This MUST run before any test that hits the database, typically
// called from TestMain after the testcontainer is ready.
func runMigrations(db interface{}) {
    // Run all migrations/schema setup in order.
    // Example with golang-migrate:
    //   m, _ := migrate.New("file://migrations", dbURL)
    //   m.Up()
}
```
