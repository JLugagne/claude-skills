# Reviewer Prompt Templates

Templates for go-reviewer to use when dispatching sub-reviewers.

## Reviewer A Prompt

Use this when dispatching the architecture + performance reviewer.

```
Launch Agent with model: sonnet and prompt:
You are reviewing a Go hexagonal architecture codebase for architecture compliance
and performance. You are Reviewer A in a dual-review process.

# Context
<content of .plan/<feature-slug>/FEATURE.md ��� summary section only>
<content of .plan/<feature-slug>/TASKS.md — task list for scope>
<list of files to review from task summaries — "Files Modified" sections>

# Instructions

You MUST fill out every row in the checklist tables below. Every item gets:
- **PASS** — verified correct
- **FAIL** — violation found (describe it)
- **N/A** — not applicable (state WHY: e.g., "no gRPC in this feature")

NEVER skip an item. NEVER leave a verdict blank.

# Hexagonal Structure

| # | Check | Verdict |
|---|-------|---------|
| H1 | Repository interfaces in `domain/repositories/<entity>/<entity>.go` (not `domain/ports/`, not flat) | |
| H2 | Service interfaces in `domain/services/<entity>/<entity>.go` (not skipped, not in app/) | |
| H3 | Repository mocks + contracts in `domain/repositories/<entity>/<entity>test/contract.go` | |
| H4 | Service mocks + contracts in `domain/services/<entity>/<entity>test/contract.go` | |
| H5 | Mocks use function-field pattern (`XxxFunc`), panic on nil (`"called not defined XxxFunc"`) | |
| H6 | Compile-time interface checks: `var _ Interface = (*Impl)(nil)` on every impl and mock | |
| H7 | Contract test function exists for every repository interface (`XxxContractTesting()`) | |
| H8 | Contract test function exists for every service interface (`XxxServiceContractTesting()`) | |
| H9 | Entity IDs are typed (`type XxxID string` + `NewXxxID()`) — not plain `string` | |
| H10 | Domain errors use `domainerror.New(code, message)` — not plain `errors.New()` sentinels | |
| H11 | All wiring in `internal/<context>/init.go` — not in `cmd/` or `main.go` | |
| H12 | Inbound handlers receive service interface from `domain/services/`, not `*app.App` | |
| H13 | Inbound adapters under `inbound/<adapter>/` — not flat `inbound/handlers/` | |
| H14 | Outbound adapters under `outbound/<adapter>/` �� not flat `outbound/repos/` | |

# Layer Boundaries

Run `go-arch-lint check` and paste the output verbatim. The `.go-arch-lint.yml` must enforce:

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
    mayDependOn: [domain]
  outbound:
    mayDependOn: [domain]
  inbound:
    mayDependOn: [domain, pkg]
  pkg:
    mayDependOn: []
```

| # | Check | Verdict |
|---|-------|---------|
| L1 | `go-arch-lint check` output (paste verbatim) | |
| L2 | domain/ has NO imports from app, inbound, outbound, or pkg | |
| L3 | app/ imports domain only | |
| L4 | outbound/ imports domain only | |
| L5 | inbound/ imports domain + pkg only (never app/) | |
| L6 | pkg/ has NO imports from internal/ | |
| L7 | No circular dependencies | |

# Type Boundaries

| # | Check | Verdict |
|---|-------|---------|
| T1 | HTTP responses use types from `pkg/<context>/` — never `domain.*` structs | |
| T2 | gRPC responses use types from `pkg/<context>/grpc/` — never `domain.*` structs | |
| T3 | Event payloads use types from `pkg/<context>/events/` — never `domain.*` structs | |
| T4 | Converters exist mapping public ↔ domain types (explicit field mapping, no embedding) | |
| T5 | No `domain.*` struct serialized directly to JSON/proto/event | |
| T6 | No cross-contamination between protocol types (HTTP ↛ gRPC, gRPC ↛ events) | |

# Performance

| # | Check | Verdict |
|---|-------|---------|
| P1 | No unbounded goroutine spawning | |
| P2 | Every goroutine has a shutdown path | |
| P3 | Every external call has a timeout | |
| P4 | Slices pre-allocated when length is known | |
| P5 | No repeated string concatenation in loops | |
| P6 | Shared mutable state protected | |
| P7 | Tests use `-race` flag | |
| P8 | Transactions kept short (no external calls inside) | |

# Coverage

Run: `go test -coverprofile=coverage.out -race -count=1 ./internal/<context>/app/... ./internal/<context>/inbound/...`
Then: `go tool cover -func=coverage.out`

| # | Check | Verdict |
|---|-------|---------|
| C1 | app/ packages at ≥80% coverage (report actual %) | |
| C2 | inbound/ packages at ≥80% coverage (report actual %) | |
| C3 | If <80%, coverage red tasks exist in TASKS.md | |
| C4 | No `t.Skip` remaining in test files for completed red phases (`grep -rn 't.Skip' internal/`) | |

outbound/ is excluded — contract tests and e2e cover it.

# Task Ordering (plan review only)

| # | Check | Verdict |
|---|-------|---------|
| O1 | Red task before its paired green task | |
| O2 | Layer order: domain → outbound → app → inbound | |
| O3 | Dependencies correctly set in TASKS.md | |
| O4 | Parallel tasks don't modify the same files | |

Do NOT create task files — the orchestrating reviewer handles that.
Do NOT attempt fixes — just report findings.
```

## Reviewer B Prompt

Use this when dispatching the security + data reviewer.

```
Launch Agent with model: sonnet and prompt:
You are reviewing a Go hexagonal architecture codebase for security vulnerabilities
and data layer quality. You are Reviewer B in a dual-review process.

# Context
<content of .plan/<feature-slug>/FEATURE.md — summary + security section>
<content of .plan/<feature-slug>/TASKS.md — task list for scope>
<list of files to review from task summaries — "Files Modified" sections>

# Instructions

You MUST fill out every row in the checklist tables below. Every item gets:
- **PASS** — verified correct
- **FAIL** — violation found (describe it)
- **N/A** — not applicable (state WHY: e.g., "no database queries in this feature")

NEVER skip an item. NEVER leave a verdict blank.

# Security

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

# API Compatibility

| # | Check | Verdict |
|---|-------|---------|
| A1 | No fields removed from response structs in `pkg/` | |
| A2 | No fields renamed in response structs | |
| A3 | No field type changes in response structs | |
| A4 | No new required fields added to request structs | |
| A5 | No enum values removed | |
| A6 | No status code changes for existing behavior | |
| A7 | No error code string changes | |

# Data Layer

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

Do NOT create task files — the orchestrating reviewer handles that.
Do NOT attempt fixes — just report findings.
```

## Opus Arbiter Prompt

Use this ONLY when Reviewer A and Reviewer B disagree on the same code.

```
Launch Agent with model: opus and prompt:
Two reviewers disagree on specific points in a code review. You are the arbiter.

# Reviewer A said:
<finding from Reviewer A>

# Reviewer B said:
<finding from Reviewer B on the same code>

# Code in question:
<relevant code files — only the specific files where they disagree>

# Feature Spec:
<relevant section of FEATURE.md>

For each point of disagreement:
1. Read both assessments
2. Read the actual code
3. Make a ruling: who is correct, and why
4. If neither is fully correct, state what the right answer is

Return ONLY:
## Ruling 1: [topic]
- **Agrees with:** [A|B|Neither]
- **Reasoning:** [2-3 sentences]
- **Action:** [create fix task | no action needed | needs more investigation]

Do NOT create task files — the orchestrating reviewer handles that.
```
