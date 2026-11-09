# Checklist: Missing Test Coverage

**Burden of proof**: for every finding, name the exact function/branch and confirm — by searching the
test files for the package — that no existing unit or integration test reaches it. Do not flag
"missing tests" for a function you haven't checked against the actual test suite.

## 1. Coverage Gaps
- [ ] **Untested critical business logic**: functions implementing core behavior with zero test
  coverage.
- [ ] **Untested error paths**: every `if err != nil` / error-return branch should have at least one
  test forcing it; flag functions where only the happy path is exercised.
- [ ] **Untested boundaries and edge cases**: empty slice/map, nil, zero value, min/max input, off-by-one
  boundary conditions.

## 2. Coverage Quality
- [ ] **Concurrency-sensitive code without a race-covering test**: verify with `go test -race` (or the
  language equivalent) on the relevant package.
- [ ] **Exported/public API with no direct test**: covered only transitively through another function's
  test, if at all.
- [ ] **Missing regression test for a recent bugfix**: check recent bugfix commits for a matching test
  addition; flag ones without one.
- [ ] **Correctness-critical logic tested only against mocks**: where an integration test against a
  real dependency is warranted to actually prove correctness.
- [ ] **Contract suites not run on every implementation**: a shared repository/port contract suite run
  against the pool-bound adapter only, never against the transaction-bound variant the commands use.
- [ ] **Integration suites that skip in CI**: a suite that `t.Skip`s when its container or emulator
  cannot start keeps CI green with nothing tested; in CI it must fail.
- [ ] **Promised orders and pagination edges**: documented list orders, "each item once" guarantees,
  and the keyset tie-break (several rows with the same sort key across a page boundary) asserted by a
  test.

## 3. Harness Fidelity
- [ ] **End-to-end harness replacing production pieces**: e2e setup that rebuilds the wiring, swaps the
  identity/context middleware or disables handlers that production runs. List what differs from the
  production entry point; every difference is a class of bug no test can catch (e.g. identity taken
  from headers in production is never exercised).
- [ ] **Refusal order untested**: no test sends an invalid body together with an unknown id, a stale
  precondition or a caller lacking the role, so the order of checks can regress silently.
- [ ] **Real-instance check tools out of date**: when the project has a tool that drives a deployed
  stack (smoke tests, chain checks), list the behaviors a single real user could observe that it does
  not check: refusal order, response headers (cache, content type, length under compression), limits
  (page size, body size, filter size), filters refused on private keys. These are exactly the bugs unit
  tests with mocks cannot see.
