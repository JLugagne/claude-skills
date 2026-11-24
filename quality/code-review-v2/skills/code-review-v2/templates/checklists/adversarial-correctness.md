# Checklist: Adversarial Correctness & Logic Review

Approach every function like someone trying to break it, not like a reviewer looking for reasons to
approve it. **Burden of proof**: for every finding, give (or point to) the minimal input or call
sequence that reaches the bad branch — a reader should immediately see why it breaks, not just that it
"looks risky".

## 1. Input Handling
- [ ] **Nil/zero-value handling**: trace every input for nil maps/slices/pointers/interfaces and
  confirm the function handles them without panicking.
- [ ] **Boundary conditions**: off-by-one errors in loops, slicing, and pagination.
- [ ] **Unsafe type assertions/conversions**: single-value type assertions that will panic on an
  unexpected type instead of the two-value safe form.
- [ ] **Text input class, all constructors at once**: build one table of EVERY constructor or parser
  that accepts a string entering the domain (IDs, names, tags, path segments, versions, keys, levels)
  and check each against the same rules: valid UTF-8, no control characters, no bidi embeddings,
  overrides or isolates (U+202A–U+202E, U+2066–U+2069), no U+2028/U+2029 in single-line values, a
  length bound, trimming. Report the table as one finding, never one constructor per round.
- [ ] **Canonical forms**: values with aliases (deprecated or bibliographic language codes such as
  `iw`/`he`, `fre`/`fr`; Unicode normalisation; case) canonicalised before being stored or compared, so
  one logical value cannot be stored twice.
- [ ] **Out-of-range values from the wire**: dates outside the store's supported range, numbers that
  overflow, cursors decoding to impossible positions reach the documented validation error, not a 500.
- [ ] **Stored data read back**: reconstituting a row must not re-run creation-time validation that can
  legitimately drift (a rule tightened later, a migrated row); one bad stored row must not make every
  read of its parent fail.
- [ ] **Fail-open defaults**: a nil or unset policy, authorizer, hook or validator that allows instead
  of refusing or panicking at construction.
- [ ] **Bound measured on another form than the one kept**: a length or size checked after a
  normalisation (trim, case fold, NFC, unescape) while the raw value is stored, forwarded or embedded.
  Every bound downstream (a cursor carrying the value, a key, a column, a header) is then computed on
  the wrong length. Build one maximal input with the padding the check ignores (thousands of spaces
  around a 200-character title) and follow it through every component, the sibling repos included.
  Seen: a title bounded after trimming upstream, kept raw downstream, produced a list cursor its own
  decoder refused.
- [ ] **Encoded worst case against every bound**: for every value written into a bounded slot (column
  or key size, cursor, header, URL, DNS label, file name, message), compute the worst case: the maximum
  of each part times the expansion of every encoding applied on the way (percent-escaping x3, JSON
  `\u` escapes x6, base64 x4/3, UTF-8 up to 4 bytes per character, separators). One table per slot:
  parts, bounds, encodings, worst case, slot bound. Seen: two 256-character ids escaped into a
  1,581-character key for a `STRING(1024)` column. The proposed action includes a test that derives the
  slot bound from the real artifact (the migration file, the decoder constant) and builds the worst
  value, so the next change to either side fails CI.
- [ ] **Input limits applied to generated output**: a bound written for one input file or field reused
  on a value the code builds (layers merged, a document re-encoded in another format, an archive
  assembled from parts). Valid inputs then produce an output the code refuses (a 413 on a download).
  For every validator called on a generated value, check that the inputs' bounds imply the output's.
- [ ] **Identifiers crossing into a narrower namespace**: an identifier one component accepts (business
  id, slug, key, name) and another uses where the rules are stricter: DNS label (at most 63 characters,
  starting with a letter, minus any suffix the consumer appends such as `-preview`), URL segment, queue
  or topic name, Kubernetes name, file name, case-insensitive lookups. The producer's rule must be a
  subset of every consumer's, or the object exists but cannot be addressed. Read the consumers in the
  sibling repos.

## 2. Error Handling
- [ ] **Swallowed errors**: `_ = err` or an ignored return value where the error should be handled or
  propagated.
- [ ] **Error shadowing**: a nested scope's `err` silently shadowing an outer one, hiding a failure.
- [ ] **Partial state on failure**: a partial write or partial state mutation left in place after an
  error, with no rollback or cleanup.
- [ ] **Refusal order**: for every write route, list the checks in the order the code runs them
  (authentication, existence/visibility, role, precondition such as `If-Match`, body validation) and
  compare with the documented order. A body validated in the handler before the use case loads the
  resource gives a refused caller a `400` where the contract says `403`/`404`/`412`. Probe with
  combinations: invalid body + unknown id, invalid body + stale precondition, invalid body + caller
  without the role.
- [ ] **Compensation that assumes failure**: cleanup of side effects (deleting a stored blob, publishing
  a cancel event) after an error that does not prove the write was rolled back (commit timeouts, lost
  connections, context cancellation after the write).

## 3. Concurrency & Assumptions
- [ ] **Decisions computed elsewhere, cached here**: a decision with a validity window (access, quota,
  lease) computed by another service at T1 and cached on arrival at T2. The expiry must be counted from
  the request start, and a window boundary falling between T1 and T2 makes the answer possibly stale
  (read again or refuse). With a mocked clock, advance time inside the mocked call to prove it.
- [ ] **Re-checks driven only by events**: anything long-lived (subscription, stream, session, cached
  grant, lease, open download) re-validated only when an event arrives. List every way its condition
  can end: an explicit event, time passing (a window or expiry that sends no event), an event lost on
  the way (at-most-once publish, broker down), a restart. Each needs a trigger; a bounded periodic
  re-check covers the lost event. Documentation that "accepts" the gap is a claim to check against the
  decisions, not a decision.
- [ ] **Unsynchronized shared mutable state**: results depending on goroutine scheduling or map
  iteration order.
- [ ] **Read-then-use races across stores**: a reference read from one store (metadata row) then used
  in another (object storage, cache) while a concurrent replace or delete can remove the target in
  between; check what the caller sees (a transient 404 on an existing resource, a dangling reference).
- [ ] **Assumed idempotency that doesn't hold**: an operation (e.g. a webhook handler) treated as safe
  to retry when a concurrent or repeated invocation would actually cause a double effect.
- [ ] **Contract mismatch**: the implementation silently contradicts what its own name or doc comment
  promises, or what the API documentation promises (status codes, defaults, limits).
- [ ] **Contract through the real chain**: shared middleware or libraries often answer a refusal
  themselves (missing token, missing claim, oversized body) with another status or shape than the docs
  promise. Check each documented refusal against the production middleware chain, not against the
  handler alone.
