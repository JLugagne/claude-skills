---
description: Orchestrates dual code review with consensus — two Sonnet reviewers
  (architecture+performance and security+data) run in parallel, Opus arbitrates
  only when they diverge. Creates fix/test task files.
---

# Go Reviewer (Dual Review with Consensus)

You orchestrate a dual review with consensus. Instead of reviewing everything
yourself, you dispatch two specialized Sonnet reviewers in parallel, then
handle consensus or escalation.

## Your Mandate

### Why dual review?

A single reviewer has blind spots. Two reviewers with different focuses catch
different things. When they agree, confidence is high. When they diverge,
the disagreement itself is the most valuable signal — it means the code has
an ambiguity worth examining closely.

### Flow

1. **Spec compliance check** (Step 0 — single pass, before dual review)
2. **Dispatch two Sonnet reviewers in parallel** (Step 1)
3. **Compare findings** (Step 2)
4. **If they agree** → merge findings, create task files, done
5. **If they diverge** → escalate divergent points to Opus arbiter (Step 3)
6. **Merge all findings** → create task files (Step 4)

## Mandatory Static Checklist

Every review MUST fill out this checklist completely. Every item gets one of:
- **PASS** — verified correct
- **FAIL** — violation found (describe it)
- **N/A** — not applicable (state WHY: e.g., "no gRPC in this feature", "no outbound adapter added")

NEVER skip an item. If you don't check it, the review is incomplete.

### Hexagonal Structure (Reviewer A)

| # | Check | Verdict |
|---|-------|---------|
| H1 | Repository interfaces in `domain/repositories/<entity>/<entity>.go` (not `domain/ports/`, not flat) | |
| H2 | Service interfaces in `domain/services/<entity>/<entity>.go` (not skipped, not in app/) | |
| H3 | Repository mocks + contracts in `domain/repositories/<entity>/<entity>test/contract.go` | |
| H4 | Service mocks + contracts in `domain/services/<entity>/<entity>test/contract.go` | |
| H5 | Mocks use function-field pattern (`XxxFunc`), panic on nil (`"called not defined XxxFunc"`) | |
| H6 | Compile-time interface checks: `var _ Interface = (*Impl)(nil)` on every implementation and mock | |
| H7 | Contract test function exists for every repository interface (`XxxContractTesting()`) | |
| H8 | Contract test function exists for every service interface (`XxxServiceContractTesting()`) | |
| H9 | Entity IDs are typed (`type XxxID string` + `NewXxxID()`) — not plain `string` | |
| H10 | Domain errors use `domainerror.New(code, message)` — not plain `errors.New()` sentinels | |
| H11 | All wiring in `internal/<context>/init.go` — not in `cmd/` or `main.go` | |
| H12 | Inbound handlers receive service interface from `domain/services/`, not `*app.App` | |
| H13 | Inbound adapters under `inbound/<adapter>/` — not flat `inbound/handlers/` | |
| H14 | Outbound adapters under `outbound/<adapter>/` — not flat `outbound/repos/` | |

### Layer Boundaries (Reviewer A)

Verified by `go-arch-lint check`. The `.go-arch-lint.yml` config must match:

```yaml
version: 3
workdir: internal
allow:
  depOnAnyVendor: true

components:
  domain:
    in: "*/domain/**"
  app:
    in: "*/app/**"
  inbound:
    in: "*/inbound/**"
  outbound:
    in: "*/outbound/**"
  pkg:
    in: "../pkg/**"

commonComponents:
  - domain

deps:
  domain:
    mayDependOn: []
  app:
    mayDependOn:
      - domain
  outbound:
    mayDependOn:
      - domain
  inbound:
    mayDependOn:
      - domain
      - pkg
  pkg:
    mayDependOn: []
```

| # | Check | Verdict |
|---|-------|---------|
| L1 | `go-arch-lint check` output (paste verbatim — zero violations expected) | |
| L2 | domain/ has NO imports from app, inbound, outbound, or pkg | |
| L3 | app/ imports domain only | |
| L4 | outbound/ imports domain only | |
| L5 | inbound/ imports domain + pkg only (never app/) | |
| L6 | pkg/ has NO imports from internal/ | |
| L7 | No circular dependencies | |

### Type Boundaries (Reviewer A)

| # | Check | Verdict |
|---|-------|---------|
| T1 | HTTP responses use types from `pkg/<context>/` — never `domain.*` structs | |
| T2 | gRPC responses use types from `pkg/<context>/grpc/` — never `domain.*` structs | |
| T3 | Event payloads use types from `pkg/<context>/events/` — never `domain.*` structs | |
| T4 | Converters exist mapping public ↔ domain types (explicit field mapping, no embedding) | |
| T5 | No `domain.*` struct serialized directly to JSON/proto/event | |
| T6 | HTTP types only in `pkg/<context>/types.go` — no proto types in HTTP responses | |
| T7 | gRPC types only in `pkg/<context>/grpc/` — no JSON-tagged structs in proto | |
| T8 | Event types only in `pkg/<context>/events/` — no HTTP or proto types in events | |

### Performance (Reviewer A)

| # | Check | Verdict |
|---|-------|---------|
| P1 | No unbounded goroutine spawning (worker pools or semaphores) | |
| P2 | Every goroutine has a shutdown path (context cancellation, done channels) | |
| P3 | Every external call has a timeout (context or client config) | |
| P4 | Slices pre-allocated when length is known | |
| P5 | No repeated string concatenation in loops (use `strings.Builder`) | |
| P6 | Shared mutable state protected (mutex, atomic, channels) | |
| P7 | Tests use `-race` flag | |
| P8 | Transactions kept short (no external calls inside transactions) | |

### Security (Reviewer B)

| # | Check | Verdict |
|---|-------|---------|
| S1 | All user inputs validated and sanitized (length limits, format checks) | |
| S2 | IDs validated as proper UUIDs | |
| S3 | Every repository method on scoped entities includes scopeID parameter | |
| S4 | Every database query filters by both entity ID AND scope ID | |
| S5 | Cross-scope access prevented at repository level | |
| S6 | Contract tests include "wrong scope" assertion | |
| S7 | All queries parameterized (no string concatenation for SQL/NoSQL/cache keys) | |
| S8 | ORDER BY / sort column names allowlisted | |
| S9 | No internal fields leaked in API responses | |
| S10 | Error messages don't expose implementation details | |
| S11 | Error responses use structured JSON `{"error":{"code":"...","message":"..."}}` | |
| S12 | Only driver-specific "not found" mapped to domain error (not all DB errors → 404) | |

### API Compatibility (Reviewer B)

| # | Check | Verdict |
|---|-------|---------|
| A1 | No fields removed from response structs in `pkg/` | |
| A2 | No fields renamed in response structs | |
| A3 | No field type changes in response structs | |
| A4 | No new required fields added to request structs | |
| A5 | No enum values removed | |
| A6 | No status code changes for existing behavior | |
| A7 | No error code string changes | |

When a breaking change is found, create a red-green task pair: red adds a test asserting the old contract, green fixes the break or documents it as intentional (versioned API).

### Data Layer (Reviewer B)

| # | Check | Verdict |
|---|-------|---------|
| D1 | Queries select only needed columns/fields | |
| D2 | WHERE/filter clauses use indexed columns | |
| D3 | No N+1 query patterns | |
| D4 | Foreign key columns used in JOINs have indexes | |
| D5 | ORDER BY columns covered by indexes | |
| D6 | Atomic multi-repo operations use transactions (or UoW) | |
| D7 | Migration DDL is idempotent (IF NOT EXISTS, etc.) | |
| D8 | Cascading deletes for scope-scoped child entities | |
| D9 | Length/size constraints on user-input fields | |

### Coverage & Test Health (Reviewer A)

| # | Check | Verdict |
|---|-------|---------|
| C1 | app/ packages at ≥80% coverage (run `go test -coverprofile` and report %) | |
| C2 | inbound/ packages at ≥80% coverage | |
| C3 | If <80%, coverage red tasks exist in TASKS.md | |
| C4 | No `t.Skip` remaining in test files for completed red phases (`grep -rn 't.Skip' internal/`) | |

outbound/ is excluded from coverage gate — contract tests and e2e cover it.

### Task Ordering (Reviewer A — plan review only)

| # | Check | Verdict |
|---|-------|---------|
| O1 | Red task before its paired green task | |
| O2 | Layer order: domain → outbound → app → inbound | |
| O3 | Dependencies correctly set in TASKS.md | |
| O4 | Parallel tasks don't modify the same files | |

## Review Process

### Step 0: Spec Compliance (single pass, before dual review)

Read `.plan/<feature-slug>/FEATURE.md` and check:
- Every acceptance criterion has at least one task that addresses it
- Every API endpoint in the spec has an e2e test task
- Every business rule has a unit or contract test task
- Every security consideration has a test + implementation task pair
- No extra functionality was added beyond the spec (scope creep)

If spec compliance fails, create task files to close the gaps BEFORE running
the dual code quality review. Spec compliance is binary — no need for consensus.

### Step 1: Dispatch Dual Sonnet Review

Launch TWO review agents in parallel with `model: sonnet`:

**Reviewer A — Architecture + Performance:**

Read the [Reviewer A Prompt](prompts.md#reviewer-a-prompt) in prompts.md.

Focus areas:
- Layer boundaries (domain/app/inbound/outbound imports)
- Service interface pattern compliance
- Type boundaries (domain types not leaking)
- Protocol type boundaries (HTTP/gRPC/events separation)
- Interface design (minimal, domain-typed)
- Mock pattern compliance
- Goroutine safety, timeout discipline
- Allocation patterns, serialization
- Race conditions, deadlock prevention
- go-arch-lint results (deterministic — run it, report output)

**Reviewer B — Security + Data:**

Read the [Reviewer B Prompt](prompts.md#reviewer-b-prompt) in prompts.md.

Focus areas:
- Input validation (length, format, UUID)
- Authorization / IDOR (scope filters in every query)
- Injection (parameterized queries, allowlisted sort columns)
- Data exposure (no internal fields in responses)
- API backward compatibility (breaking changes in pkg/ types)
- Query optimization (N+1, missing indexes, column selection)
- Index coverage (FK indexes, ORDER BY indexes, composites)
- Transaction safety (short transactions, no external calls inside)
- Schema design (CHECK constraints, cascading deletes, ID validation)

### Step 2: Compare Findings

Read both review summaries. Categorize each finding:

**Agreed findings** — both reviewers flagged the same issue, or one reviewer
found an issue in their focus area that the other didn't contradict:
→ Accept directly. Create task files.

**Non-overlapping findings** — one reviewer found something in their focus area
that the other didn't review (expected — they have different scopes):
→ Accept directly. Create task files.

**Divergent findings** — the two reviewers disagree on the same piece of code:
- Reviewer A says it's fine, Reviewer B says it's a problem (or vice versa)
- They both flag the same code but with different assessments
- One says "breaking change", the other says "non-breaking"
→ Collect for Opus arbitration.

### Step 3: Opus Arbitration (only if divergence)

If there are divergent findings, dispatch an Opus arbiter.
Read the [Opus Arbiter Prompt](prompts.md#opus-arbiter-prompt) in prompts.md.

The arbiter:
- Reads both reviewer summaries
- Reads the specific code files in question
- Makes a ruling for each divergent point
- Explains the reasoning (this goes into the review report for learning)

If there are NO divergent findings, skip this step entirely — don't burn Opus
tokens when Sonnets agree.

### Step 4: Merge and Create Task Files

Combine all accepted findings (agreed + non-overlapping + arbiter rulings)
into a single review report. Create task files for each issue:

**Security issues → red-green pair:**
```markdown
# task-rev-1: [SECURITY-RED] Test <Entity>: <vulnerability class>
## Skill: go-test-writer
## Phase: red
## Depends On: task-1
...
```
```markdown
# task-rev-2: [SECURITY-GREEN] Fix <Entity>: <vulnerability class>
## Skill: go-dev
## Phase: green
## Depends On: task-rev-1
...
```

**DBA fixes → single task:**
```markdown
# task-rev-3: [DBA-FIX] Add missing index for xxx list query
## Skill: go-dev
## Phase: green
...
```

Append ALL new tasks to `.plan/<feature-slug>/TASKS.md`.

## Summary Output

Return the merged checklist tables from both reviewers with all verdicts filled in, plus:

```
## Review Report

### Spec Compliance: PASS|GAPS_FOUND
- [gaps, if any]

### Checklist Results
[Merged H1-H14, L1-L7, T1-T8, P1-P8, C1-C3, O1-O4 from Reviewer A]
[Merged S1-S12, A1-A7, D1-D9 from Reviewer B]
FAIL count: N    N/A count: N    PASS count: N

### Consensus: N agreed, N non-overlapping, N divergent
- [divergent points, if any]

### Opus Arbitration: [SKIPPED — no divergence | N rulings]
- [rulings, if any]

### Tasks Created
- task-rev-1: [title]
- task-rev-2: [title]
```

## Guidelines

- Read each file at most once.
- Only review and create plan files, not implementation code. Fixes go through the red-green cycle.
- Pair every security red-test with a green task. Unpaired red tests stay red forever.
- Be specific in test descriptions — name the field, method, and expected behavior.
- If something is already correct, say so. Don't invent issues.
- Append new tasks to `.plan/<feature-slug>/TASKS.md`. The runner discovers work by re-reading this file.
