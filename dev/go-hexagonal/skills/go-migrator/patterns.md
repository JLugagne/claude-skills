# Go Migrator Patterns

## backfill-sql

Idempotent SQL backfill pattern. The WHERE clause ensures running this migration twice is safe -- rows already updated are skipped.

```sql
-- NNN_backfill_xxx_status.up.sql
-- Idempotent: only updates rows that haven't been migrated
-- The WHERE clause is the idempotency guard — without it, re-running
-- the migration would overwrite intentional status changes made after
-- the first run
UPDATE xxx
SET status = 'active'
WHERE status IS NULL;
-- For large tables, prefer the Go-based batched approach below
-- Raw SQL UPDATE on millions of rows locks the table for the duration
```

## batched-data-transform

Go-based batched migration for large tables. Key design choices: batch size limits lock duration, FOR UPDATE SKIP LOCKED prevents deadlocks with concurrent application queries, and the loop terminates when no rows remain.

```go
// internal/<context>/outbound/<adapter>/migrations/backfill_split_name.go
// Place migration code alongside the SQL migrations so they share
// the same migration numbering and execution order
func BackfillSplitName(ctx context.Context, pool *pgxpool.Pool) error {
    // batchSize controls how many rows are locked per transaction
    // 500 is a good default — small enough to avoid long locks,
    // large enough to make progress quickly
    const batchSize = 500
    for {
        result, err := pool.Exec(ctx, `
            WITH batch AS (
                -- FOR UPDATE SKIP LOCKED is critical: it prevents this
                -- migration from deadlocking with application queries
                -- that also lock rows. Locked rows are simply skipped
                -- and processed in the next batch iteration
                SELECT id FROM users
                WHERE first_name IS NULL AND full_name IS NOT NULL
                LIMIT $1
                FOR UPDATE SKIP LOCKED
            )
            UPDATE users u
            SET first_name = split_part(u.full_name, ' ', 1),
                last_name = split_part(u.full_name, ' ', 2)
            FROM batch
            WHERE u.id = batch.id
            -- The WHERE join ensures only the batch rows are updated,
            -- keeping the transaction small and the lock duration short
        `, batchSize)
        if err != nil {
            return fmt.Errorf("backfill split name: %w", err)
        }
        // When no rows are affected, all eligible rows have been migrated
        // This is the natural termination condition — no sentinel values needed
        if result.RowsAffected() == 0 {
            break
        }
        // Optional: add a small sleep between batches to reduce
        // database load during peak traffic. Omit for off-hours runs.
    }
    return nil
}
```

## migration-test

Testcontainers-based migration test. The structure is always: seed old state, run migration, assert new state, then run again to verify idempotency. The idempotency check is the most important assertion -- it catches migrations that corrupt data on re-run.

```go
func TestMigration_NNN_BackfillXxxStatus(t *testing.T) {
    // setupTestDB uses testcontainers to spin up a real PostgreSQL instance
    // This ensures migrations are tested against actual PostgreSQL behavior,
    // not an in-memory mock that may differ in edge cases
    pool := setupTestDB(t)

    // Seed: insert rows in the OLD state (before migration)
    // Use realistic data — edge cases in seed data catch bugs that
    // synthetic "row1, row2" data misses
    seedOldData(t, pool)

    // Run the migration — this is the code under test
    err := runMigration(pool, "NNN_backfill_xxx_status")
    require.NoError(t, err)

    // Assert: rows are now in the NEW state
    // Query the actual database — don't trust the migration's return value
    var count int
    err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM xxx WHERE status IS NULL").Scan(&count)
    require.NoError(t, err)
    assert.Equal(t, 0, count, "all rows should have status after migration")

    // Assert: idempotent — run the same migration again
    // This is the CRITICAL check: the second run must be a no-op
    // If the migration corrupts data on re-run, this catches it
    err = runMigration(pool, "NNN_backfill_xxx_status")
    require.NoError(t, err)
    // Optionally re-assert the count to verify data wasn't corrupted
}
```
