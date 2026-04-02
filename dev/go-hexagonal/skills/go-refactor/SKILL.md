---
description: Safe refactoring agent. First documents all inbound surfaces (HTTP, gRPC, message queues, etc.), creates exhaustive e2e tests with testcontainers to lock behavior, then plans and executes the rewrite with type-level compatibility guarantees. Use when restructuring, rewriting, or migrating existing code.
---

# Go Refactor

You perform safe refactors by locking existing behavior with exhaustive tests before changing anything. The principle: **if you can't prove the system still works identically after the refactor, you haven't finished.**

## The Three Phases

### Phase 1: Document (read-only — zero code changes)
### Phase 2: Lock (tests only — zero implementation changes)
### Phase 3: Rewrite (implementation only — zero test changes)

Never mix phases. Each phase has a clear gate before proceeding to the next.

---

## Phase 1: Document All Inbound Surfaces

Before touching any code, produce a complete inventory of every way the system receives input and produces output.

### What to document

For each inbound surface, create `.refactor/<surface>.md`:

#### HTTP Endpoints

Read the [HTTP Surface Documentation](patterns.md#http-surface-doc) pattern in patterns.md when writing this.

#### gRPC Services

Read the [gRPC Surface Documentation](patterns.md#grpc-surface-doc) pattern in patterns.md when writing this.

#### Message Queue Consumers

Read the [Queue Surface Documentation](patterns.md#queue-surface-doc) pattern in patterns.md when writing this.

#### Scheduled Jobs / Cron

Read the [Cron Surface Documentation](patterns.md#cron-surface-doc) pattern in patterns.md when writing this.

### How to discover surfaces

1. **Read `main.go`** — find all route registrations, gRPC server registrations, queue consumers, cron setups
2. **Read handler files** — document every public method, its request/response types, error codes
3. **Read proto files** — document every RPC, message type, enum
4. **Read queue consumer files** — document every subscription, message schema, side effects
5. **Grep for `HandleFunc`, `RegisterService`, `Subscribe`, `Consume`, `AddFunc`** — catch anything main.go missed

### Gate: Phase 1 → Phase 2

Create `.refactor/SURFACES.md` summarizing all surfaces found.

Read the [Surfaces Summary Template](patterns.md#surfaces-summary) pattern in patterns.md when writing this.

**Ask the user to review** `.refactor/SURFACES.md` before proceeding. Missing a surface means the refactor could silently break an integration.

---

## Phase 2: Lock Behavior with Tests

Create exhaustive e2e tests that exercise every documented surface. These tests are the **safety net** — they must all pass before AND after the refactor. If a test fails after the refactor, the refactor broke something.

### Test principles

1. **Test the contract, not the implementation.** Assert on input types, output types, status codes, error codes, side effects — not on internal function calls.
2. **Use testcontainers for everything.** Real database, real message queue, real cache. No mocks.
3. **Seed deterministic data.** Fixed UUIDs, fixed timestamps where possible. Tests must be reproducible.
4. **Test exact types.** Unmarshal responses into the actual response struct types. If a field is renamed, added, or removed, the test fails at compile time or assertion time.

### Test structure

Create one test file per surface in `tests/e2e-refactor/`.

Read the [E2E Test Directory Structure](patterns.md#e2e-test-structure) pattern in patterns.md when writing this.

#### HTTP tests
For each endpoint documented in Phase 1:
- **Happy path**: valid request → expected response (unmarshal into typed struct, assert every field)
- **Every error code**: trigger each documented error → assert status code + error JSON
- **IDOR**: cross-scope access → 404
- **Edge cases**: empty lists return `[]`, boundary values, missing optional params

#### gRPC tests
For each RPC:
- **Happy path**: valid request → expected response (assert every field of the protobuf message)
- **Every error code**: trigger each → assert gRPC status code
- **Type compatibility**: the request and response proto messages must match the documented schema

#### Queue tests
For each consumer:
- **Publish a test message** → assert the expected side effect (e.g., notification created in DB)
- **Publish duplicate message** → assert idempotency (no duplicate entity)
- **Publish malformed message** → assert it's dead-lettered or logged, not silently dropped
- **Verify the message schema**: marshal a struct to JSON, publish it, verify the consumer accepts it

#### Type compatibility tests

Read the [Type Compatibility Tests](patterns.md#type-compat-tests) pattern in patterns.md when writing this.

### Gate: Phase 2 → Phase 3

Run all tests: `go test ./tests/e2e-refactor/... -count=1 -v`

**Every test must pass.** If any test fails, the existing code has a bug — fix the test or the code BEFORE proceeding to the refactor. The tests must faithfully represent the current behavior, even if that behavior is wrong (document it as a known issue in `.refactor/KNOWN_ISSUES.md`).

**Ask the user to review** the test results and confirm the behavior is correctly captured.

---

## Phase 3: Plan and Execute the Rewrite

Now that behavior is locked, plan the refactor.

### Create `.refactor/REWRITE_PLAN.md`

Read the [Rewrite Plan Template](patterns.md#rewrite-plan) pattern in patterns.md when writing this.

### Execute the rewrite

Use the go-runner agent to dispatch tasks. Each task:
- Modifies ONLY implementation files (never tests)
- Is followed by a full test run to verify no regression
- Is small enough to revert if tests fail

### Type compatibility enforcement

During the rewrite, the type tests from Phase 2 act as compile-time and runtime guards:
- If you rename a JSON field → `json.Decode` fails or assertion fails
- If you remove a response field → assertion on that field fails
- If you change a status code → status code assertion fails
- If you change an error code string → error code assertion fails
- If you change a protobuf field number → gRPC client gets wrong data
- If you change a queue message schema → consumer test fails to process

**The tests are the contract. The contract doesn't change. Only the implementation behind it changes.**

---

## Guidelines

- Read each file at most once.
- Phase 1 is read-only. Do not modify any code. Only create `.refactor/` documentation files.
- Phase 2 creates tests only. Do not modify implementation files. Tests must pass against the CURRENT code.
- Phase 3 modifies implementation only. Do not modify test files. Tests must pass against the NEW code.
- If a test fails in Phase 3, the refactor broke something. Fix the implementation, not the test.
- If the current code has a bug discovered in Phase 2, document it in `.refactor/KNOWN_ISSUES.md` and write the test to match current (buggy) behavior. Fix the bug as a separate task after the refactor.
- Ask the user to review after Phase 1 and Phase 2 before proceeding. Missing a surface or misunderstanding current behavior makes the refactor unsafe.
- The refactor is successful when: all Phase 2 tests pass, all existing tests pass, `go build ./...` passes, and the user confirms the new structure is correct.
