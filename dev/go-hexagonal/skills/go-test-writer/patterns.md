# Go Test Writer — Code Patterns

Reference patterns for each test level. Each sample includes inline comments explaining WHY each line matters and HOW to adapt it to your domain.

---

## Unit Test (App Layer) {#unit-test-app-layer}

```go
func TestApp_CreateXxx_Success(t *testing.T) {
    // Use context.Background() — app layer tests don't need request-scoped values.
    ctx := context.Background()

    // Function-based mock: wire ONLY the methods this test exercises.
    // If CreateFunc is the only method called, leave all other Func fields nil.
    // A nil-func that gets called will panic — that's a signal your test scope is wrong.
    mock := &xxxtest.MockXxxRepository{
        CreateFunc: func(ctx context.Context, ...) error {
            // Return nil to simulate a successful write.
            // To test error handling, return a domain error here instead.
            return nil
        },
    }

    // newAppWith wires the app service with only the mock you control.
    // If the app requires multiple repositories, pass mocks for all of them
    // but only set Func fields for the ones this specific test touches.
    a := newAppWith(mock)

    result, err := a.CreateXxx(ctx, ...)

    // require.NoError stops the test immediately — subsequent asserts
    // on `result` would nil-pointer panic if err != nil.
    require.NoError(t, err)

    // assert.Equal for independent field checks — lets you see ALL
    // mismatches in one run rather than failing on the first one.
    assert.Equal(t, expected, result.Field)
}
```

---

## Contract Test (Repository Layer) {#contract-test-repository}

```go
// These run inside the XxxContractTesting function in
// domain/repositories/<entity>/<entity>test/contract.go.
// They are REUSABLE — called from both mock-based unit tests
// and real adapter tests (testcontainers). Write them once, run twice.

t.Run("Contract: Create stores and FindByID retrieves", func(t *testing.T) {
    // Always use domain.NewXxxID() to generate a fresh ID.
    // Never hard-code IDs in contract tests — they run against
    // real databases where collisions cause flaky failures.
    item := domain.Xxx{ID: domain.NewXxxID(), Field: "value"}

    err := repo.Create(ctx, item)
    // require stops the test here if Create fails — FindByID
    // would be meaningless against a missing record.
    require.NoError(t, err)

    found, err := repo.FindByID(ctx, item.ID)
    require.NoError(t, err)

    // Compare individual fields, not the whole struct. Adapters may
    // populate metadata fields (CreatedAt, UpdatedAt) that weren't
    // in the original — a DeepEqual would fail on those.
    assert.Equal(t, item.Field, found.Field)
})

t.Run("Contract: FindByID wrong scope returns error", func(t *testing.T) {
    // IDOR contract: attempting to read an entity using a different
    // project/tenant scope MUST return an error, not the entity.
    // This is the most critical security contract — adapters that
    // skip the scope filter will pass unit tests but fail this one.
    _, err := repo.FindByID(ctx, otherProjectID, item.ID)
    require.Error(t, err)
})
```

---

## Repository Adapter Contract Test {#repository-adapter-contract-test}

```go
func TestXxxRepositoryContract(t *testing.T) {
    // setupTestDB launches a testcontainer (e.g., Postgres via tcpostgres),
    // runs all migrations, and returns a connected pool.
    // The container is torn down automatically via t.Cleanup.
    pool := setupTestDB(t)

    // Instantiate the REAL adapter — same constructor production code uses.
    // This proves the adapter satisfies the port interface against real
    // infrastructure, not just against an in-memory mock.
    repo := NewXxxRepository(pool)

    // Run the SHARED contract tests defined in <entity>test/contract.go.
    // setupProject is a helper that seeds a project/tenant so
    // scoped queries have valid foreign keys.
    // If the adapter breaks a contract, this line catches it.
    xxxtest.XxxContractTesting(t, repo, setupProject)
}
```

---

## App Service Contract Test {#app-service-contract-test}

```go
func TestAppXxxContract(t *testing.T) {
    // Real database via testcontainers — same as adapter tests.
    pool := setupTestDB(t)

    // Wire REAL repositories — not mocks. This tests the full
    // app -> repo -> database -> app round-trip.
    projectRepo := pg.NewProjectRepository(pool)
    xxxRepo := pg.NewXxxRepository(pool)

    // Use the same app.New constructor production code uses.
    // If the constructor signature changes, this test breaks at compile
    // time — catching wiring errors before they reach staging.
    a := app.New(projectRepo, xxxRepo)

    // Test full use cases: app -> repo -> db -> app.
    // These catch integration bugs that unit tests with mocks miss:
    // wrong column names, missing foreign keys, broken queries.
    t.Run("CreateXxx persists and can be retrieved", func(t *testing.T) {
        result, err := a.CreateXxx(ctx, projectID, "test")
        require.NoError(t, err)

        found, err := a.GetXxx(ctx, projectID, result.ID)
        require.NoError(t, err)

        // Assert on every field that matters — not just the ID.
        // A query that returns the wrong row will pass an ID-only check.
        assert.Equal(t, "test", found.Name)
    })
}
```

---

## gRPC E2E Tests {#grpc-e2e-tests}

Use `google.golang.org/grpc/test/bufconn` for in-process gRPC testing (no real port needed).

```go
func TestMain(m *testing.M) {
    ctx := context.Background()

    // Start testcontainers (Postgres, etc.)
    container, err := startTestContainer(ctx)
    if err != nil {
        log.Fatalf("testcontainer: %v", err)
    }

    // Connect, run migrations, seed data
    client := connectToContainer(ctx, container)
    runMigrations(client)
    seedTestData(client)

    // Create bufconn listener — in-process, no real port needed.
    // 1MB buffer is sufficient for most test payloads.
    lis = bufconn.Listen(1024 * 1024)

    // Start gRPC server with real repos (same wiring as production)
    srv := grpc.NewServer()
    handler := setupGRPCHandler(client) // wire real repos → app → handler
    pb.RegisterXxxServiceServer(srv, handler)
    go srv.Serve(lis)

    // Tests use grpc.Dial with bufconn dialer
    code := m.Run()

    srv.GracefulStop()
    container.Terminate(ctx)
    os.Exit(code)
}

// bufDialer creates a connection through the in-process listener.
// Use this with grpc.DialContext in each test.
func bufDialer(context.Context, string) (net.Conn, error) {
    return lis.Dial()
}
```

gRPC tests MUST cover:
- Full CRUD lifecycle via gRPC client
- Error codes: `codes.InvalidArgument`, `codes.NotFound`, `codes.PermissionDenied`
- IDOR: access scope B's data from scope A's context → `codes.NotFound`
- Proto field presence: every response field is present and correctly typed
- Same seed data as HTTP e2e tests — both surfaces test the same domain

---

## E2E Test Setup (TestMain + Seed) {#e2e-test-setup}

```go
func TestMain(m *testing.M) {
    ctx := context.Background()

    // Start testcontainers for ALL external dependencies.
    // Use the appropriate testcontainers module for your infrastructure:
    //   postgres: tcpostgres.Run(ctx, "postgres:17", ...)
    //   redis:    tcredis.Run(ctx, "redis:7", ...)
    //   rabbitmq: tcrabbitmq.Run(ctx, "rabbitmq:3-management", ...)
    //   kafka:    tckafka.Run(ctx, "confluentinc/cp-kafka:7.5.0", ...)
    //   mongo:    tcmongo.Run(ctx, "mongo:7", ...)
    //
    // Pin image tags to major versions for reproducibility.
    // Never use :latest — it causes flaky CI when upstream pushes a breaking change.
    container, err := startTestContainer(ctx)
    if err != nil {
        // log.Fatalf in TestMain is correct — there's no *testing.T yet.
        // A failed container means every test would fail anyway.
        log.Fatalf("testcontainer: %v", err)
    }

    // Connect, run migrations, seed data — in that order.
    // Running migrations here (not in each test) keeps the suite fast
    // and guarantees every test sees the same schema version.
    client := connectToContainer(ctx, container)
    runMigrations(client)
    seedTestData(client)

    // Build the FULL HTTP server with real repos — no mocks.
    // This is the same wiring production uses, just pointed at
    // the testcontainer instead of a real database.
    testServer = setupServer(client)

    // m.Run() executes all Test* functions in the package.
    code := m.Run()

    // Teardown in reverse order of setup.
    // Close server first (stops accepting requests), then client
    // (flushes connections), then container (removes the Docker resource).
    testServer.Close()
    client.Close()
    container.Terminate(ctx)
    os.Exit(code)
}

func seedTestData(client interface{}) {
    // Seed at least:
    // - 2 scopes/tenants (for IDOR testing) — e.g., projectA and projectB.
    //   Without two scopes, you cannot test cross-tenant isolation.
    // - Multiple entities in scope A (for list/filter/search testing).
    //   A single entity can't verify pagination, ordering, or filtering.
    // - At least 1 entity in scope B (for cross-scope isolation assertions).
    //   This entity must NEVER appear in scope-A query results.
    //
    // Use FIXED IDs (UUIDs you define as constants) for deterministic assertions.
    // Random IDs make tests order-dependent and failures hard to reproduce.
}
```
