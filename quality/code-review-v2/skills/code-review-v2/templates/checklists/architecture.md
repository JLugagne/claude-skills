# Checklist: Architecture & Structural Design

## 1. Boundaries & Coupling
- [ ] **Layering violations**: a lower/inner layer importing or depending on a higher/outer layer
  (e.g. domain logic importing an HTTP handler package), or circular package dependencies.
- [ ] **Leaky abstractions**: internal implementation details (ORM row types, raw HTTP request objects,
  driver-specific types) leaking through a package's public API instead of being translated to
  domain-owned types at the boundary.
- [ ] **Cross-domain coupling bypassing defined seams**: direct calls between unrelated bounded
  contexts that skip the ports/interfaces meant to mediate them, or shared mutable global state used
  as an implicit communication channel.
- [ ] **Storage choices leaking into ports and the public contract**: a port parameter with a single
  valid value (a reserved collection, table or bucket name injected by every caller), use cases returning
  the storage type so callers decode it again, or a private storage layout exposed as a public filter or
  sort contract (renaming a stored field then breaks clients, internal keys become filterable).
- [ ] **Write-capable dependencies held where only reads are needed**: a service holding the full
  repository outside its unit of work, so a future write compiles and silently skips the transaction,
  the audit row or the atomic companion write. Check which methods are actually called.

## 2. Module Shape (Deep vs. Shallow)
- [ ] **God objects / god files**: a file, struct, or package accumulating unrelated responsibilities
  (SRP violation) — check whether it can be named with a single clear sentence; if not, it's likely
  doing too much.
- [ ] **Shallow modules**: an interface or abstraction with a large public surface but little behavior
  actually hidden behind it — a thin wrapper that doesn't earn the indirection it costs the reader.
- [ ] **Near-copy live code**: handlers, use cases or queries that differ only by one parameter (the
  collection, the use-case method, the response type), each copy free to drift; name the shared shape
  that would replace them.
- [ ] **Premature abstraction**: interfaces with exactly one implementation and no test-double need,
  or factory/strategy patterns solving a variability problem the codebase doesn't actually have yet.

## 3. Consistency
- [ ] **Inconsistent error-handling strategy**: mixed panics vs. returned errors for equivalent
  situations, or inconsistent error-wrapping conventions across packages that otherwise share a layer.
- [ ] **Hidden global state / singletons** used in place of explicit dependency injection, making the
  code harder to test or reason about in isolation.
- [ ] **Pattern drift**: new code diverges from an architecture pattern already established elsewhere
  in the same repo for the equivalent kind of component, with no stated reason.
- [ ] **Validation duplicated across layers**: the public contract (DTO validator tags) repeating domain
  rules and running before the domain, which both duplicates the rule and changes which error a caller
  gets (see the refusal-order check in adversarial-correctness).
- [ ] **One business rule encoded twice** (e.g. a visibility rule in a per-row SQL fragment and in a
  list query) with no named specification (contract test suite) keeping both in step.

## 4. Composition & Documentation
- [ ] **Composition root not reusable**: the wiring function reads global config or builds concrete
  adapters itself, so end-to-end tests rebuild the wiring by hand and a wiring bug passes them. Compare
  the test setup with the production entry point line by line.
- [ ] **Documented architecture contradicted by the code**: README, architecture docs and agent
  instruction files describing a call chain, a security control or a limit that the code (or the
  sibling repos in scope) does not implement.
