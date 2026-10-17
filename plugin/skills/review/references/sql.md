# SQL, migrations and schema

Candidates only: each must pass the SKILL.md gates. The project's schema and naming doc wins over this file. A
missing-index or slow-query finding names the query and the expected row count.

## Schema

- A column ending `_id` with no foreign key; a foreign key with no index (Postgres does not create one) and no
  explicit `ON DELETE`.
- A polymorphic reference (`target_id` + `target_type`); an EAV table; mutually exclusive booleans where one status
  belongs.
- `JSONB` holding known fields or a list of ids that a table should; a comma-separated list in a column.
- Money as float; app timestamps without time zone; a reserved word as a name.
- Soft delete without every unique index partial on `deleted_at IS NULL` and every query filtering it.
- A hand-maintained derived column that a generated column or the query can compute.

## Migrations

- Schema change and data backfill in one migration; a backfill that is not batched.
- On a table with live traffic: an index built without `CONCURRENTLY`, a type change or `NOT NULL` that rewrites or
  locks it, a drop before the previous release stopped reading it.
- An edited migration that has already run anywhere it matters (follow the project's rule on what counts).

## Queries

- String concatenation or interpolation into SQL; `ORDER BY` from request input without an allow-list.
- An unbounded query on a growing table; deep `OFFSET` (keyset instead); pagination without a tiebreaker column.
- A non-sargable predicate (`date(created_at) = ?`, implicit cast); `LIKE '%x%'` without a trigram index.
- `COUNT(*) > 0` for existence; `DISTINCT` hiding a join fan-out; a query per row in a loop.
- Check-then-insert without a unique constraint; a read-modify-write without a lock or version.
