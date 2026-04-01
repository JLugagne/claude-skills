---
description: "Use before claiming ANY work is complete — after go-dev green phase, after go-fixer recovery, after go-refactor rewrite, before go-runner marks a task done. Evidence before assertions, always."
---

# Go Verify

Claiming work is complete without verification is dishonesty, not efficiency.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the commands in THIS message, you cannot claim they pass.

## The Gate (run this every time)

```
BEFORE claiming any task is done:

1. IDENTIFY: What commands prove this claim?
2. RUN: Execute ALL of them fresh
3. READ: Full output — exit codes, failure counts, warnings
4. VERIFY: Does output confirm the claim?
   → NO:  State actual status with evidence
   → YES: State claim WITH evidence
5. ONLY THEN: Report completion
```

## Go-Specific Verification Matrix

| Claim | Required Commands | NOT Sufficient |
|-------|-------------------|----------------|
| Build passes | `go build ./...` exit 0 | "Should compile" |
| Tests pass | `go test ./... -count=1 -race` — 0 failures | Previous run, partial test |
| Red phase done | Tests compile AND fail for expected reason | Tests that error (not fail) |
| Green phase done | Previously-red tests now pass + full suite green | Single test passes |
| E2E tests pass | `go test ./tests/e2e/... -count=1 -v -race` | Unit tests passing |
| No race conditions | `-race` flag shows no warnings | Tests pass without `-race` |
| Migrations work | Testcontainer starts, seeds, and tests pass | "Migration SQL looks correct" |
| Refactor safe | ALL Phase 2 e2e-refactor tests still pass | "Logic unchanged" |
| Pipeline task done | build + specific tests + full suite | Build alone |
| Feature complete | ALL of the above + acceptance criteria checked | "Tests pass" |

## Verification Sequences by Role

### go-dev (green phase)
```bash
# 1. Build
go build ./...

# 2. Specific tests (the ones that were red)
go test ./internal/<context>/... -run TestSpecificPattern -count=1 -v -race

# 3. Full suite (no regressions)
go test ./... -count=1 -race
```

All three must pass. Report the output.

### go-test-writer (red phase)
```bash
# 1. Build (tests must compile)
go build ./...

# 2. Run the new tests — they MUST FAIL
go test ./internal/<context>/... -run TestSpecificPattern -count=1 -v

# Expected: FAIL (not ERROR)
# The failure must be because the feature is missing, not because of typos or import errors
```

Report: which tests failed, what the failure message was, confirm it's the RIGHT failure.

### go-runner (after each task)
```bash
# After scaffold
go build ./...
go test ./... -count=1

# After each green task
go build ./...
go test ./... -count=1 -race
```

### go-fixer (after recovery)
```bash
# Whatever was failing must now pass
go test ./internal/<context>/... -run TestThatWasFailing -count=1 -v -race

# Plus no new breakage
go test ./... -count=1 -race
```

### go-refactor (after Phase 3 rewrite)
```bash
# Phase 2 locking tests
go test ./tests/e2e-refactor/... -count=1 -v -race

# Full suite
go test ./... -count=1 -race
```

### Feature completion (before handoff to user)
```bash
# Full build
go build ./...

# Full test suite with race detection
go test ./... -count=1 -race

# Check acceptance criteria from FEATURE.md — line by line
# Each criterion must have evidence (test name, output, or manual verification)
```

## Red Flags — STOP

If you catch yourself thinking:
- "Should work now"
- "I'm confident this is correct"
- "The logic is right, no need to run"
- "Linter passed, so it compiles" (linter ≠ `go build`)
- "Tests passed earlier" (stale — run again)
- "Partial check is enough"
- About to write "Done!" or "All green!" without command output above

**ALL of these mean: run the commands first.**

## Reporting Format

```
## Verification

### Build
$ go build ./...
[exit code 0 — PASS]

### Specific Tests
$ go test ./internal/notification/... -run TestCreateNotification -count=1 -v -race
--- PASS: TestCreateNotification (0.02s)
--- PASS: TestCreateNotification_EmptyMessage (0.01s)
--- PASS: TestCreateNotification_WrongProject (0.01s)
PASS
[3/3 pass — GREEN]

### Full Suite
$ go test ./... -count=1 -race
ok   github.com/org/service/internal/notification/...  2.341s
ok   github.com/org/service/internal/project/...       1.872s
[all packages pass — NO REGRESSIONS]

### Race Detector
[no race conditions detected]
```

## Guidelines

- Run commands fresh — every time, even if you "just ran them."
- Always include `-race` for Go tests. Race conditions are silent killers.
- Always use `-count=1` to disable test caching.
- Report actual output, not summaries. "Tests pass" is a claim. The output is evidence.
- If any verification step fails, STOP and fix before claiming completion.
