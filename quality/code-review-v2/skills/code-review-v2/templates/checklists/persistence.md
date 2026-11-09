# Checklist: Persistence & Database Usage

Review how the code uses its database as a cost model, not as a syntax check: what each query reads per
call, what each write rewrites, and what happens at the transaction edges. **Burden of proof**: quote
the query and either an `EXPLAIN` plan (from the runtime verification step, when available) or a
written trace of what the planner must do (rows visited per call, as a function of data size). "This
query might be slow" is not a finding; "page N costs O(visible rows) because the cursor and LIMIT sit
outside the UNION" is.

## 1. Query Shape
- [ ] **Pagination that is not really paginated**: cursor, `LIMIT` or filters applied to an outer query
  over a `UNION`, CTE, `DISTINCT` or aggregate the planner cannot push them into, so every page
  enumerates the whole candidate set. Check each branch: does it walk an index in page order and stop?
- [ ] **Branches merged with `UNION` that can yield duplicates inside one branch** (one row per share,
  per role, per tag): a per-branch `LIMIT n` then returns fewer than `n` distinct items and the merged
  page silently skips rows.
- [ ] **Unscoped scans hidden behind a join**: a branch filtering on a column of the joined table
  (team, app, collection) while its driving index lacks it, so it reads every row of that kind in the
  tenant before filtering.
- [ ] **Narrowing options bolted onto the general query**: an option such as "owned only" or "status
  = X" added as one more predicate on the outer query, while every branch, join and lateral subquery of
  the general case still runs; a narrower dedicated query would use one index.
- [ ] **Full rows loaded for metadata-only use cases**: large `JSONB`/`TEXT`/`BYTEA` columns selected by
  queries whose callers only read ids, owners, revisions or flags.
- [ ] **Cost formulas on user-controlled input**: containment (`@>`), `LIKE '%..%'`, regex or array
  operators evaluated per row with an unbounded filter value.

## 2. Indexes
- [ ] **Index/query mismatch**: column order that cannot serve the query's equality-then-range shape,
  a missing or wrong partial predicate (`WHERE deleted_at IS NULL` on one side only), an index ranging
  on a column no query ranges on.
- [ ] **Indexes no query uses**: confirmed by searching every query of the table; they still cost every
  write.
- [ ] **Broad expensive indexes**: GIN/trigram indexes over whole documents across every tenant and
  type, unlikely to be selective, paid on every insert and non-HOT update.
- [ ] **Indexes on write-only tables** (audit, events) with no reader yet.

## 3. Writes
- [ ] **Updates rewriting unchanged large columns**: a single `UPDATE` statement used for every change,
  resending the full document (TOAST rewrite, WAL, GIN re-extraction, never HOT) when only metadata
  changed.
- [ ] **Redundant existence checks** inside statements that already run in a transaction right after a
  guarded read or write of the same row.
- [ ] **Denormalized copies without a writer that keeps them consistent**, or immutable source columns
  that could be denormalized to make a hot query index-only and are not.

## 4. Transaction Edges
- [ ] **Compensation after an ambiguous commit**: code that deletes a side effect (blob, message,
  external call) when `Commit` returns an error, although a timeout or lost connection after `COMMIT`
  was sent can mean the transaction did commit. The adapter must tell "rejected" from "unknown".
- [ ] **Rollback or cleanup on the request context**: `Rollback(ctx)` with a context that may already be
  cancelled, which makes the driver close the pooled connection instead of returning it.
- [ ] **Repository methods that open their own transactions**, or write-capable repositories reachable
  outside the unit of work (see architecture).
- [ ] **One page, several snapshots**: a page or view assembled from several independent strong reads
  (page, then its children) can mix states of a concurrent write; use one read-only transaction when
  the result must be consistent.
- [ ] **Per-commit limits**: count the mutations of the largest legitimate write (cascading deletes of
  interleaved children, every secondary-index entry) against the store's limit (Spanner 80,000).

## 5. Pool, Timeouts, Migrations, Growth
- [ ] **Pool size and server-side timeouts left at driver defaults**: e.g. pgxpool `MaxConns =
  max(4, NumCPU)` where `NumCPU` is the node's core count in Kubernetes; no `statement_timeout`,
  `lock_timeout` or `idle_in_transaction_session_timeout`.
- [ ] **Migrations**: concurrent starts (advisory lock taken then treated as failure), lock and unlock
  on different pooled connections, statements that are not idempotent, and file names tracked in a
  table shared with other bounded contexts without a context prefix (future collisions).
- [ ] **Unbounded growth**: append-only tables (audit, events, trash) with no retention, purge or
  partitioning plan.
