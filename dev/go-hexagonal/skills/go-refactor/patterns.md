# Go Refactor Patterns

Reference patterns for the go-refactor skill. Each section is linked from SKILL.md.

---

## HTTP Surface Documentation {#http-surface-doc}

Template for documenting HTTP endpoints in `.refactor/<surface>.md`. Every endpoint needs its full request/response contract captured so Phase 2 tests can lock each path.

```markdown
# HTTP Surface: <context>

## Endpoints

### GET /api/v1/projects/{projectID}/notifications
<!-- One section per endpoint. Path params, query params, and body all documented separately. -->
- **Request**: path param `projectID` (UUID), query param `read` (optional bool)
<!-- List EVERY response code the handler can return. Missing one means Phase 2 tests will have a gap. -->
- **Response 200**: `{"items": [NotificationResponse], "total": int}`
- **Response 400**: `{"error": {"code": "INVALID_PROJECT_ID", "message": "..."}}`
- **Response 404**: `{"error": {"code": "PROJECT_NOT_FOUND", "message": "..."}}`
<!-- Consumes/Produces makes it easy to cross-reference with Type Compatibility tests later. -->
- **Consumes**: projectID (UUID string)
- **Produces**: NotificationResponse {id, project_id, type, message, read, created_at}

### POST /api/v1/projects/{projectID}/notifications
- **Request**: `{"type": "project_created|project_updated|project_archived", "message": "1-500 chars"}`
- **Response 201**: NotificationResponse
<!-- Each error code becomes a distinct test case in Phase 2. -->
- **Response 400**: INVALID_NOTIFICATION_TYPE, INVALID_MESSAGE
- **Consumes**: CreateNotificationRequest {type, message}
- **Produces**: NotificationResponse
```

---

## gRPC Surface Documentation {#grpc-surface-doc}

Template for documenting gRPC services. Map each RPC to its request/response message types and error codes so tests can assert on exact proto field presence.

```markdown
# gRPC Surface: <service>

## RPCs

### CreateNotification(CreateNotificationRequest) -> CreateNotificationResponse
<!-- Document field-level constraints (UUID format, string length) so tests can cover validation paths. -->
- **Request fields**: project_id (string/UUID), type (enum), message (string 1-500)
- **Response fields**: notification (Notification message)
<!-- Use the canonical gRPC status codes, not custom strings. Tests will assert on these exactly. -->
- **Error codes**: INVALID_ARGUMENT, NOT_FOUND
<!-- Consumes/Produces ties back to the Type Compatibility tests in Phase 2. -->
- **Consumes**: CreateNotificationRequest protobuf
- **Produces**: CreateNotificationResponse protobuf
```

---

## Queue Surface Documentation {#queue-surface-doc}

Template for documenting message queue consumers. Idempotency behavior is critical to capture because Phase 2 tests will publish duplicate messages to verify it.

```markdown
# Queue Surface: <queue/topic>

## Consumers

### project.events (RabbitMQ / Kafka / NATS)
<!-- List every binding/topic pattern. A missed binding means a missed test. -->
- **Binding/Topic**: project.events.created, project.events.updated, project.events.archived
<!-- The exact JSON schema is what Phase 2 tests will marshal into a struct and publish. -->
- **Message schema**: {"project_id": "UUID", "event_type": "string", "timestamp": "RFC3339"}
<!-- Side effects are what Phase 2 tests will query the DB to verify after publishing. -->
- **Side effects**: Creates a Notification entity in the database
- **Consumes**: ProjectEvent JSON
- **Produces**: Notification (in database)
<!-- Idempotency key determines how the duplicate-message test is constructed. -->
- **Idempotency**: keyed on (project_id, event_type, timestamp) -- duplicate messages must not create duplicate notifications
```

---

## Cron Surface Documentation {#cron-surface-doc}

Template for documenting scheduled jobs. Phase 2 tests will trigger these manually and assert on DB state before/after.

```markdown
# Cron Surface: <job>

## Jobs

### cleanup-old-notifications (runs daily)
<!-- Document the trigger mechanism so tests know how to invoke it manually. -->
- **Trigger**: cron schedule
<!-- Side effects are what the test asserts on: row count before vs after. -->
- **Side effects**: Deletes notifications older than 90 days
- **Consumes**: nothing (time-based)
- **Produces**: DELETE queries against notifications table
```

---

## Surfaces Summary Template {#surfaces-summary}

The summary table goes in `.refactor/SURFACES.md`. This is the Phase 1 gate artifact -- the user reviews this before Phase 2 begins. Missing a row in this table means the refactor could silently break an integration.

```markdown
# Inbound Surfaces

<!-- One row per surface. The count column helps the user spot if you missed endpoints. -->
| Surface | Type | Endpoints/RPCs/Topics | File |
|---------|------|----------------------|------|
| HTTP API | http | 6 endpoints | .refactor/http.md |
| Notification gRPC | grpc | 4 RPCs | .refactor/grpc.md |
| Project Events | rabbitmq | 3 bindings | .refactor/queue-project-events.md |
| Cleanup Job | cron | 1 job | .refactor/cron-cleanup.md |

## Types Consumed (inputs)
<!-- List every input type across ALL surfaces. These become the "Consumes" side of Type Compatibility tests. -->
- CreateNotificationRequest {type, message}
- ProjectEvent {project_id, event_type, timestamp}
- ...

## Types Produced (outputs)
<!-- List every output type across ALL surfaces. These become the "Produces" side of Type Compatibility tests. -->
- NotificationResponse {id, project_id, type, message, read, created_at}
- ...
```

---

## E2E Test Directory Structure {#e2e-test-structure}

One file per surface type. `setup_test.go` handles the shared testcontainers lifecycle so individual test files stay focused on contract assertions.

```
tests/e2e-refactor/
  setup_test.go              # TestMain: testcontainers, migrations, seed, server
                             # -- starts real DB, queue, cache; runs migrations; seeds fixed data
  http_test.go               # Every HTTP endpoint
                             # -- one subtest per endpoint x scenario (happy, each error, IDOR, edge)
  grpc_test.go               # Every gRPC RPC
                             # -- one subtest per RPC x scenario
  queue_test.go              # Every queue consumer (publish test message, assert side effect)
                             # -- tests publish, duplicate, malformed for each consumer
  cron_test.go               # Every cron job (trigger manually, assert side effect)
                             # -- tests trigger the job function directly, assert DB state
  types_test.go              # Type compatibility assertions
                             # -- compile-time + runtime checks that API contract types haven't changed
```

---

## Type Compatibility Tests {#type-compat-tests}

These tests are the backbone of refactor safety. They make real requests and unmarshal into the exact documented types. If any field is renamed, removed, or retyped, these tests break immediately -- either at compile time (struct mismatch) or at assertion time (empty/nil field).

```go
// These tests ensure the refactor doesn't change the API contract.
// They compare the actual types used by the system against the documented types.
// IMPORTANT: these must use the REAL response struct types, not anonymous structs,
// so that field renames cause compile errors, not silent data loss.

func TestHTTPResponseTypes(t *testing.T) {
    // Make a real HTTP request against the testcontainer-backed server.
    // Never mock the HTTP layer -- the goal is to test the full stack.
    resp := env.get(t, "/api/v1/projects/"+projectID+"/notifications")

    // Unmarshal into the EXACT response struct the API documents.
    // Using the real struct type means added/removed fields cause compile errors.
    var body struct {
        Items []NotificationResponse `json:"items"`
        Total int                    `json:"total"`
    }
    err := json.NewDecoder(resp.Body).Decode(&body)
    require.NoError(t, err, "response must unmarshal into documented type")

    // Assert every field is present and correctly typed.
    // Each assertion maps to one line in the Phase 1 surface doc's "Produces" section.
    require.NotEmpty(t, body.Items)
    item := body.Items[0]
    assert.NotEmpty(t, item.ID, "id field must be present")
    assert.NotEmpty(t, item.ProjectID, "project_id field must be present")
    assert.NotEmpty(t, item.Type, "type field must be present")
    assert.NotEmpty(t, item.Message, "message field must be present")
    assert.NotNil(t, item.CreatedAt, "created_at field must be present")
    // read is a bool -- can be false, so just check it exists in the JSON.
    // Adapt: for other bool fields, parse raw JSON and check key presence instead of value.
}

func TestGRPCResponseTypes(t *testing.T) {
    // Make a real gRPC call through the testcontainer-backed server.
    // The client is generated from the same proto files the server uses.
    resp, err := client.GetNotification(ctx, &pb.GetNotificationRequest{...})
    require.NoError(t, err)

    // Assert the protobuf message has all documented fields populated.
    // If a field number changes in the proto, the client silently gets zero-value -- these assertions catch that.
    assert.NotEmpty(t, resp.Notification.Id)
    assert.NotEmpty(t, resp.Notification.ProjectId)
    // ... add one assertion per field listed in the Phase 1 gRPC surface doc.
    // Adapt: for optional/nullable proto fields, use assert.NotNil instead of assert.NotEmpty.
}
```

---

## Rewrite Plan Template {#rewrite-plan}

The rewrite plan goes in `.refactor/REWRITE_PLAN.md`. Each migration step must be small enough to revert if tests fail. The verification block runs after EVERY step, not just at the end.

```markdown
# Rewrite Plan

## Goal
<!-- State the architectural change in one sentence. This keeps scope from creeping. -->
[What the refactor achieves -- e.g., "migrate from gorilla/mux to stdlib", "split monolith into bounded contexts"]

## Constraints
<!-- These constraints are non-negotiable. If any is violated, the refactor is incomplete. -->
- All tests in tests/e2e-refactor/ must pass after the rewrite
- No changes to any test file during the rewrite
- No changes to API contracts (same request/response types, same status codes, same error codes)
- No changes to message schemas (same JSON structure, same topic/binding names)
- No changes to proto definitions (same message types, same field numbers)

## Changes

### Files to modify
<!-- One line per file. The "why" prevents drive-by changes that aren't part of the refactor. -->
- [file] -- [what changes and why]

### Files to create
- [file] -- [purpose]

### Files to delete
<!-- Only delete files that are fully replaced. If in doubt, keep the old file and deprecate. -->
- [file] -- [why it's no longer needed]

## Migration steps (ordered)
<!-- Each step must be independently verifiable. If step 3 breaks tests, you revert step 3 only. -->
1. [step] -- [what changes, what tests should still pass]
2. [step] -- [incremental, verify tests after each step]

## Verification
<!-- Run this block after EVERY migration step, not just at the end. -->
After each step:
1. `go build ./...`
2. `go test ./tests/e2e-refactor/... -count=1 -v` -- ALL tests pass
3. `go test ./... -count=1` -- no regressions
```
