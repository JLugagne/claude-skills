---
description: "Use when encountering any bug, test failure, or unexpected behavior in Go code — before proposing fixes. Enforces root cause investigation through the hexagonal layers. Also use when go-fixer circuit breaker has fired and the root cause is still unclear."
---

# Go Debugger (Systematic)

Random fixes waste tokens and create new bugs. This skill enforces root cause investigation before any fix attempt, adapted to Go hexagonal codebases.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes. If you haven't traced the error through the hexagonal layers, you don't understand it.

## When to Use

- Test failure (unit, contract, e2e)
- Build failure after a pipeline step
- go-fixer circuit breaker fired and the underlying issue is unclear
- Runtime error or panic in development
- Performance regression
- Race condition detected by `-race`
- Testcontainer failing to start or connect

**Use ESPECIALLY when:**
- "Just one quick fix" seems obvious
- You've already tried a fix and it didn't work
- The error message doesn't match where you're looking
- go-fixer was invoked but couldn't resolve the issue

## Phase 1: Root Cause Investigation

### 1.1 Read Error Messages Completely

Don't skip past errors. Go errors wrap context at each layer — read the full chain:

```
create notification: find project by id: dial tcp: connection refused
```

This tells you: app layer (`create notification`) → repository call (`find project by id`) → infrastructure (`dial tcp: connection refused`). The root cause is infrastructure, not domain logic.

### 1.2 Identify the Failing Layer

In hexagonal architecture, the error originates in one of these layers:

| Layer | Symptoms | Where to Look |
|-------|----------|----------------|
| **Domain** | Validation errors, business rule violations | `internal/*/domain/` |
| **App** | Orchestration failures, wrong service wiring | `internal/*/app/` |
| **Outbound** | DB errors, queue errors, cache misses | `internal/*/outbound/` |
| **Inbound** | Wrong HTTP status, malformed response, routing | `internal/*/inbound/` |
| **Infrastructure** | Connection failures, migration errors, testcontainer | `cmd/`, `docker-compose`, migrations |
| **Test** | Wrong assertion, bad test data, mock not wired | `*_test.go`, `*test/contract.go` |

**Trace inward**: start from the error surface (test output, HTTP response) and trace through inbound → app → domain → outbound until you find the originating layer.

### 1.3 Reproduce Consistently

```bash
# Run the specific failing test with verbose output and race detection
go test ./internal/<context>/... -run TestSpecificName -count=1 -v -race
```

If it's intermittent:
- `-count=10` to reproduce race conditions
- Check testcontainer readiness (is the DB fully initialized?)
- Check for shared mutable state between tests

### 1.4 Check Recent Changes

```bash
# What changed since the last green state?
git diff HEAD~1 --name-only
git log --oneline -5
```

Focus on:
- New imports (circular dependency?)
- Modified domain types (field renamed/removed?)
- Migration changes (column type mismatch?)
- Mock changes (function signature drift?)

### 1.5 Gather Evidence at Layer Boundaries

For multi-layer failures, add temporary diagnostic logging at each boundary:

```go
// Temporary — remove after debugging
log.Printf("DEBUG [inbound] request: %+v", req)
log.Printf("DEBUG [app] calling repo with projectID=%s entityID=%s", projectID, entityID)
log.Printf("DEBUG [outbound] SQL result rows=%d err=%v", rows, err)
```

Run once. Read the output. Identify WHERE the data goes wrong. Remove the logging.

## Phase 2: Pattern Analysis

### 2.1 Find a Working Example

In hexagonal codebases, similar patterns repeat. Find an entity that works correctly with the same pattern:

```bash
# Find similar repository methods
grep -r "FindByID" internal/*/domain/repositories/ --include="*.go"

# Find similar test patterns
grep -r "TestCreate" internal/*/outbound/ --include="*_test.go"
```

### 2.2 Diff Against Working Code

Compare the broken code against the working example:
- Same parameter order? (broad to narrow: scopeID, entityID)
- Same error handling pattern? (driver-specific not-found check)
- Same mock wiring? (function-based with panic on unset)
- Same converter pattern? (domain ↔ public types)

### 2.3 Check Cross-Layer Contracts

Common hexagonal debugging patterns:

| Issue | Likely Cause | Check |
|-------|-------------|-------|
| `nil pointer` in handler | Service interface not injected | `init.go` or `main.go` wiring |
| `called not defined XxxFunc` | Mock not configured in test | Test setup function |
| Wrong HTTP status code | Converter or error mapping wrong | `inbound/handlers/` error switch |
| Entity not found (but exists) | Missing scope filter in query | `outbound/` SQL WHERE clause |
| Migration fails on re-run | Non-idempotent DDL | Missing `IF NOT EXISTS` |
| Test passes alone, fails in suite | Shared test state | `TestMain` setup/teardown |

## Phase 3: Hypothesis and Testing

### 3.1 Form a Single Hypothesis

State it clearly:
```
HYPOTHESIS: The FindByID query in outbound/pg/notification_repository.go
filters by notification_id only, missing the project_id scope filter.
This causes the e2e IDOR test to pass (finding the entity across scopes)
when it should return not-found.
```

### 3.2 Test Minimally

Make the SMALLEST possible change to test the hypothesis. ONE variable at a time.

**Do NOT:**
- Fix multiple things at once
- "Improve" nearby code while you're there
- Add features to the fix

### 3.3 Verify

```bash
go build ./...
go test ./internal/<context>/... -count=1 -v -race
```

- If fix works → Phase 4
- If fix doesn't work → form NEW hypothesis (don't pile more changes)

## Phase 4: Implementation

### 4.1 Create a Failing Test First

Use TDD even for bugfixes:

```go
func TestNotification_FindByID_WrongProject_ReturnsNotFound(t *testing.T) {
    // Create notification in project A
    // Attempt to find it from project B
    // Assert: domain.ErrNotificationNotFound
}
```

Run it. Confirm it fails for the right reason.

### 4.2 Fix the Root Cause

ONE change. At the source, not at the symptom.

### 4.3 Verify Completely

```bash
go build ./...
go test ./... -count=1 -race  # Full suite, not just the failing test
```

### 4.4 Escalation Rules

| Attempts | Action |
|----------|--------|
| 1 fix failed | Re-analyze with new information. Return to Phase 1. |
| 2 fixes failed | Step back. Are you in the right layer? Re-trace from the error surface. |
| 3+ fixes failed | **STOP.** This is likely an architectural issue, not a local bug. Report to user with: what you investigated, what you tried, why you think the architecture needs discussion. |

## Summary Output

When done, return:
```
## Debug Report

### Root Cause
[One sentence: what was actually wrong and in which layer]

### Evidence
[The specific error trace or test output that confirmed the root cause]

### Fix
- `path/to/file.go` — [what changed]

### Verification
- go build: PASS
- go test (specific): PASS
- go test (full suite): PASS
- Race detector: CLEAN

### Regression Test
- `path/to/test_file.go:TestName` — [what it proves]
```

## Red Flags — STOP and Return to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see"
- "I don't fully understand but this might work"
- "It's probably a [layer] issue" (without evidence)
- Proposing fixes before tracing through the layers
- Modifying multiple files simultaneously "to see if it helps"
- Same error after 2 fix attempts

## Guidelines

- Read each file at most once.
- Always trace errors through hexagonal layers before guessing.
- A fix without a regression test is not a fix — it's a prayer.
- If the circuit breaker on go-fixer fired and you still can't find the root cause, escalate to the user honestly. "I don't understand this" is more valuable than a wrong fix.
