---
name: sqlite-optimization
description: Use this skill when writing, reviewing, or optimizing ANY Ecto query, SQL fragment, migration, or database index. Use PROACTIVELY when the user mentions "query", "SQL", "database", "index", "migration", "FTS", "full-text search", "json_extract", "json_each", "GROUP BY", "subquery", "performance", "slow query", "N+1", "Ecto query", "Repo.all", "Repo.one", or asks about database design. Also use when adding WHERE clauses, JOINs, or changing how data is fetched. The SQLite-specific patterns in this project are easy to miss and cause silent performance regressions.
---

# SQLite Optimization

Project-specific SQLite query patterns, index strategies, and migration conventions.
These rules are load-bearing — dev datasets are small enough to hide problems that
degrade production performance.

## Checklist Before Writing Any Database Query

1. **Check for existing expression indexes** before writing a query. Your `WHERE` or
   `GROUP BY` clause must match the index expression textually.

2. **If no index exists for your query**, add one in a migration with an `up`/`down`
   and a comment explaining which query it helps.

3. **FTS5 tables are trigger-synced** — never INSERT/UPDATE/DELETE directly on
   `records_search_index`. Write to `records` instead.

4. **Config-driven constants.** Pagination defaults and magic numbers live in
   `config/config.exs`, read via `Application.compile_env!/2`.

## Expression Indexes & SQL Text Matching

SQLite treats `json_extract(column, '$.path')` and `column ->> '$.path'` as
**semantically equal but textually distinct**. If an expression index uses
`json_extract`, your query MUST use the same text:

```elixir
# Index definition (in migration):
# CREATE INDEX idx_records_format ON records(json_extract(data, '$.format'));

# CORRECT — matches index text
from(r in Record, where: fragment("json_extract(?, '$.format')", r.data) == "vinyl")

# WRONG — won't use the index
from(r in Record, where: fragment("? ->> '$.format'", r.data) == "vinyl")
```

Same applies to `GROUP BY` — match the expression index exactly:

```elixir
# Index exists on: json_extract(r.data, '$.artist_name')
# CORRECT GROUP BY:
from(r in Record,
  group_by: fragment("json_extract(?, '$.artist_name')", r.data)
)
```

## Subquery Materialization with `limit: -1`

When a date-filtered subquery feeds an outer `GROUP BY`, SQLite may flatten the
subquery and prefer the wrong composite index. **Force materialization with
`limit: -1`**:

```elixir
filtered = from(t in Track,
  where: t.scrobbled_at >= ^start_date,
  limit: -1  # forces materialization, preserves range-scan index
)

from(t in subquery(filtered),
  group_by: t.artist_name,
  select: %{artist: t.artist_name, count: count()}
)
|> Repo.all()
```

## Correlated Scalar Subqueries

For **small-LIMIT result enrichment** from large lookup tables, use correlated scalar
subqueries instead of `LEFT JOIN`. Cost scales with the outer LIMIT, not the lookup
table size:

```elixir
# CORRECT — cost proportional to LIMIT
from(r in Record,
  limit: 20,
  select: %{
    id: r.id,
    title: r.title,
    scrobble_count: fragment(
      "(SELECT count(*) FROM scrobbled_tracks WHERE record_id = ?)", r.id
    )
  }
)

# WRONG — joins entire scrobbled_tracks table
from(r in Record,
  left_join: s in subquery(counts_query), on: s.record_id == r.id,
  limit: 20
)
```

## FTS5 Full-Text Search

The `records_search_index` table is an FTS5 **virtual table auto-synced via database
triggers**. Treat it as read-only:

```elixir
# CORRECT — insert into the source table, triggers sync FTS
Repo.insert!(%Record{title: "Dark Side of the Moon", ...})

# CORRECT — read from FTS index
from(ri in "records_search_index",
  where: fragment("records_search_index MATCH ?", ^query)
)

# WRONG — never write directly to FTS
Repo.insert_all("records_search_index", [...])
```

## JSON Column Patterns

### json_each() for expanding arrays

```elixir
from(r in Record,
  cross_join: fragment("json_each(?)", r.genres),
  where: fragment("value = ?", ^genre),
  select: r
)
```

### json_extract() for field access

```elixir
from(r in Record,
  where: fragment("json_extract(?, '$.format') = ?", r.data, ^format)
)
```

## Materialized Views via Triggers

SQLite lacks native materialized views. Use explicit `up`/`down` in migrations for
non-reversible DDL. Read-only schemas for materialized/view tables:

```elixir
# Read-only schema (no PK, no changeset, no timestamps)
defmodule Records.RecordRelease do
  use Ecto.Schema
  @primary_key false
  schema "record_releases" do
    field :record_id, :binary_id
    field :release_id, :string
    field :cover_hash, :string
    field :purchased_at, :utc_datetime
  end
end
```

## Migration Conventions

Every migration must:
- Provide **both `up` and `down`** for any `execute` block
- Comment every index explaining which query it helps
- Use explicit triggers for materialized views

```elixir
def change do
  execute(
    # UP
    "CREATE INDEX idx_records_purchase_date ON records(purchased_at);",
    # DOWN — always provided
    "DROP INDEX IF EXISTS idx_records_purchase_date;"
  )
end
```

## Query Patterns to Avoid

| Anti-pattern | Why | Fix |
|-------------|-----|-----|
| `Repo.all()` then `Enum.filter()` | Loads entire table into memory | Filter in SQL with `where:` |
| `Enum.map()` with inline `Repo` calls | N+1 queries | Use preload or joins |
| `preload: [:association]` on large result sets | Cartesian product in memory | Use `join:` and `select:` |
| Dynamic `order_by` without corresponding index | Full table sort | Add composite index matching sort columns |
| `distinct: true` without index | Temporary B-tree | Add index on distinct columns |

## Using QueryReporter to Verify

Before committing a query change, use the query-reporter skill to capture the actual
SQL and verify:
1. The query uses the expected indexes (check `EXPLAIN QUERY PLAN`)
2. No unexpected full table scans
3. Subqueries are materialized when needed

```bash
# In SQLite console (mise run dev:sqlite-console):
EXPLAIN QUERY PLAN SELECT ...;
```
