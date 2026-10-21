# SQL, migrations and schema

Candidates only: each must pass the SKILL.md gates. The project's schema and naming doc wins over this file. A
missing-index or slow-query finding names the query and the expected row count; a hot-path query or index change
asks for `EXPLAIN (ANALYZE, BUFFERS)` on realistic row counts (inside `BEGIN; … ROLLBACK;` for DML), not a plain
`EXPLAIN` on a dev table. Impact grading and pools: [performance.md](performance.md). PostgreSQL assumed.

## Schema

- A column ending `_id` with no foreign key; a foreign key with no index (Postgres does not create one, so every
  parent `DELETE` scans the child table) and no explicit `ON DELETE`.
- A polymorphic reference (`target_id` + `target_type`); an EAV table; mutually exclusive booleans where one status
  belongs.
- `JSONB` holding known fields or a list of ids that a table should; a comma-separated list in a column. A JSONB
  filter must use `@>` on a GIN index or a matching expression index; `jsonb_path_ops` cannot serve `?`.
- Money as float; an instant stored as `timestamp` without time zone (use `timestamptz`); a reserved word as a name.
  `+ interval '24 hours'` where a calendar day is meant crosses DST wrongly: `interval '1 day'`.
- Soft delete without every unique index partial on `deleted_at IS NULL` and every query filtering it. The query
  must repeat the literal `deleted_at IS NULL`: a bind parameter cannot prove a partial-index predicate.
- A hand-maintained derived column that a generated column or the query can compute.

## Migrations

- Schema change and data backfill in one migration. A backfill is its own migration or job, batched by key range with
  one transaction per batch, never one `UPDATE` over the table.
- On a table with live traffic, each of these needs the safe form:
  - `CREATE INDEX` is `CONCURRENTLY`, in its own migration (Flyway: `executeInTransaction=false`); a failed build
    leaves an INVALID index, so the migration drops it first or checks `indisvalid`.
  - `ADD FOREIGN KEY` / `CHECK` is `NOT VALID`, then `VALIDATE CONSTRAINT` later; `SET NOT NULL` follows a validated
    `CHECK (c IS NOT NULL)`, otherwise it scans the table under an exclusive lock.
  - `ADD COLUMN` with a volatile default (`gen_random_uuid()`, `clock_timestamp()`), an identity or a stored generated
    column rewrites the table; a constant default does not.
  - `ALTER COLUMN TYPE` that is not binary-coercible (`int` to `bigint` on a large table) rewrites table and
    indexes: expand, dual-write, backfill in batches, swap.
  - Any `ACCESS EXCLUSIVE` DDL waits behind one long `SELECT` and queues every later query behind itself: a short
    `lock_timeout` and a retrying runner.
- A drop or rename of a column or table that the previous release still reads or writes (expand/contract).
- An edited migration that has already run anywhere it matters (follow the project's rule on what counts).

## Queries

- String concatenation or interpolation into SQL; `ORDER BY` from request input without an allow-list.
- An unbounded query on a growing table; deep `OFFSET` (keyset: `ORDER BY (sort, unique)` and a row-value
  predicate `(a, b) < (?, ?)`); any `LIMIT`/`OFFSET` without an `ORDER BY` that gives a unique order.
- A predicate that wraps the indexed column (`lower(c) = ?`, `date(ts) = ?`, `c + 1 = ?`) with no index on the same
  expression: rewrite as a range on the bare column.
- `LIKE 'x%'` on a non-C locale without `text_pattern_ops`; `LIKE '%x%'`, `ILIKE` or a regex without a trigram index,
  or with a term under three characters.
- `NOT IN` over a subquery or a nullable list (one NULL returns no rows): `NOT EXISTS`. `BETWEEN` on timestamps counts
  the boundary row in both periods: `>= start AND < end`.
- `OR` across columns or tables on a big table: ask for the plan or a `UNION` rewrite, and check its duplicate
  semantics.
- `COUNT(*)` of a big table on every page load; `COUNT(*) > 0` for existence; `DISTINCT` hiding a join fan-out; a
  query per row in a loop.
- A composite index with the range column before the equality columns; a covering `INCLUDE` with wide columns on a
  high-churn table.
- Full-text search whose `to_tsvector(...)` arguments differ from the index expression: the index is ignored.

## Transactions and locking

- Check-then-insert without a unique constraint: `INSERT … ON CONFLICT (cols)`. `DO NOTHING` returns no row for a
  conflict, and a batch that proposes the same key twice fails with a cardinality error.
- A read-modify-write without a lock or version; multi-row `SELECT … FOR UPDATE` in different orders on different code
  paths (deadlock): lock in one order, `ORDER BY id`. Queue consumers use `SKIP LOCKED`.
- A transaction that stays open across a network call or file work (see performance.md).

Sources: PostgreSQL documentation (ALTER TABLE, CREATE INDEX, INSERT, indexes, explicit locking); use-the-index-luke.com;
GitLab and Crunchy Data migration guides; Cybertec on `OR` and `COUNT`; Vlad Mihalcea on batching and pagination.
