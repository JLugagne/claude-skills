# Checklist: Memory Usage & Resource Efficiency

## 1. Growth & Cleanup
- [ ] **Unbounded growth**: caches, maps, slices, or buffered channels that grow without eviction or a
  bound as load increases — trace what removes entries and under what condition.
- [ ] **Missing resource cleanup**: files, network connections, DB rows/statements, tickers, or
  goroutines started but never closed/stopped/deferred, especially on error-return paths where cleanup
  is easy to forget.
- [ ] **Retained references preventing GC**: long-lived structures (caches, closures, global
  registries) holding references to large short-lived objects, keeping them alive longer than needed.

## 2. Allocation Patterns
- [ ] **Unnecessary large allocations**: loading an entire file/response into memory
  (`io.ReadAll` on an unbounded stream) where streaming would do; slice pre-allocation sized from
  unbounded user input.
- [ ] **Inefficient data structures**: O(n) linear scans where a map/set would do, repeated full-slice
  copies inside loops, string concatenation in a loop instead of a builder type.
- [ ] **Per-request peak memory**: maximum page size × maximum item size × number of copies held at once
  (driver row buffer, decoded value, compacted copy, response encoding), compared with the deployment's
  memory limit. One legitimate request must not be able to OOM the process.
- [ ] **Large value copies in hot paths**: passing/returning large structs by value in frequently
  called code where a pointer would avoid the copy.

## 3. Lifetime
- [ ] **Deferred cleanup with no later trigger**: cleanup that runs only as a side effect of a write (a
  collection after each commit, a purge after each insert) and skips what is still within a grace period
  or beyond its batch. If no further write comes, the skipped items stay forever. Require a trigger that
  does not depend on the next write (a periodic sweep, a rerun scheduled after the grace), and a rerun
  while a batch comes back full.
- [ ] **Goroutine/object lifetime mismatches**: a goroutine or long-lived object outliving its intended
  scope with no cancellation path — flag the specific leak, not just "no context passed".
