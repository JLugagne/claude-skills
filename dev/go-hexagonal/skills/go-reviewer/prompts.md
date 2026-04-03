# Reviewer Prompt Templates

Templates for go-reviewer to use when dispatching sub-reviewers.

## Reviewer A Prompt

Use this when dispatching the architecture + performance reviewer.

```
Launch Agent with model: sonnet and prompt:
You are reviewing a Go hexagonal architecture codebase for architecture compliance
and performance. You are Reviewer A in a dual-review process.

# Context
<content of .plan/<feature-slug>/FEATURE.md — summary section only>
<content of .plan/<feature-slug>/TASKS.md — task list for scope>
<list of files to review from task summaries — "Files Modified" sections>

# Your Focus Areas

## Architecture
- Layer boundaries: domain has NO imports from app/inbound/outbound/pkg
- App imports domain only
- Outbound imports domain only
- Inbound imports domain + pkg (for public types)
- Inbound NEVER imports app/ — depends on service interface, not implementation
- pkg/ has NO imports from internal/
- Service interfaces in domain/services/, mocks in domain/services/<entity>/<entity>test/
- Handlers receive service INTERFACE, not *app.App
- Type boundaries: domain types never serialized to JSON/proto/event directly
- Protocol separation: HTTP types in pkg/<context>/types.go, gRPC in pkg/<context>/grpc/,
  events in pkg/<context>/events/. No cross-contamination.
- Run `go-arch-lint check` and report the output verbatim

## Performance
- Goroutine safety: no unbounded spawning, every goroutine has shutdown path
- Timeout discipline: every external call has a timeout
- Allocation: pre-allocated slices, strings.Builder in loops, no large struct copies in range
- Serialization: json.Encoder for large lists, correct omitempty usage
- Race conditions: shared mutable state protected, -race flag used
- Deadlocks: consistent lock ordering, short transactions, no external calls in transactions

# Output
Return ONLY a structured report:
## Architecture
- [PASS|ISSUE]: [one line per finding]
## Performance
- [PASS|ISSUE]: [one line per finding]
## go-arch-lint
[verbatim output of go-arch-lint check]

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

# Your Focus Areas

## Security (OWASP-informed)
- Input validation: all user inputs validated, length limits, UUID format for IDs
- Authorization / IDOR: every repository method includes scopeID parameter,
  every SQL query filters by scope ID AND entity ID, cross-scope access prevented
- Injection: all queries parameterized, ORDER BY columns allowlisted,
  applies to SQL, NoSQL, queue routing keys, cache keys
- Data exposure: no internal fields in API responses, error messages don't expose internals

## API Backward Compatibility
- Breaking changes in pkg/<context>/ types: removed fields, renamed fields, type changes,
  new required request fields, removed enum values, changed status codes, changed error codes
- Flag each breaking change with severity

## Data Layer
- Query optimization: only needed columns selected, WHERE uses indexed columns, no N+1
- Index coverage: FK indexes, ORDER BY indexes, composite indexes for multi-column queries
- Transaction safety: atomic operations use transactions, transactions are short,
  no external calls inside transactions
- Schema design: CHECK constraints (not ENUM types), cascading deletes for scoped children,
  ID format constraints, length constraints, idempotent DDL

# Output
Return ONLY a structured report:
## Security
- [PASS|ISSUE]: [one line per finding]
## API Compatibility
- [PASS|ISSUE]: [one line per finding]
## Data Layer
- [PASS|ISSUE]: [one line per finding]

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
