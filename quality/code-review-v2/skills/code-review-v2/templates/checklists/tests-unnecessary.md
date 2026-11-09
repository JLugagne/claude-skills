# Checklist: Unnecessary or Low-Value Tests

**Burden of proof**: quote the specific assertion or setup that makes the test low-value. "This test
looks pointless" is not a finding — the quoted code is.

## 1. Tests That Prove Nothing
- [ ] **Mock-only assertions**: the test asserts against a mock/stub's own configured return value,
  never validating real behavior of the code under test.
- [ ] **Tautological tests**: assertions that can never fail (comparing a hardcoded value to itself,
  testing a trivial getter/setter with no logic behind it).
- [ ] **Tests-for-the-framework**: the test only confirms a third-party library or language runtime
  behaves as documented, contributing nothing to confidence in this codebase's own logic.

## 2. Tests That Cost More Than They're Worth
- [ ] **Duplicate coverage**: multiple tests exercising the exact same code path with no new input or
  edge case between them.
- [ ] **Implementation-coupled tests**: assertions on private field values or internal call order that
  break on a harmless refactor with no actual behavior change — a churn magnet.
- [ ] **Overlong/unfocused tests**: one test function exercising many unrelated behaviors, making
  failures hard to diagnose and the intent hard to read.
- [ ] **Flaky-by-design tests**: reliance on real sleeps/timing, unseeded randomness, or real
  network/clock dependence, which don't reliably prove anything and erode trust in the suite.
