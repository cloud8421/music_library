---
id: ML-202
title: Make JSON aggregate ordering deterministic
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 05:16"
labels:
  - sqlite
  - listening-stats
dependencies: []
references:
  - lib/music_library/listening_stats.ex
documentation:
  - "https://sqlite.org/changes.html#version_3_44_0"
  - "https://sqlite.org/lang_aggfunc.html"
  - docs/project-conventions.md
  - docs/architecture.md
modified_files:
  - lib/music_library/listening_stats.ex
  - test/music_library/listening_stats_test.exs
  - docs/architecture.md
priority: medium
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Use SQLite aggregate ORDER BY support to make JSON arrays built by `json_group_array(json_object(...))` deterministic in listening statistics. Current matching-record payloads are constructed in SQL without an aggregate ordering clause, so record order can vary. Preserve existing semantics while making the order stable for recent activity and top-album metadata.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 All SQL `json_group_array(json_object(...))` matching-record payloads in ListeningStats use an explicit aggregate ORDER BY clause.
- [ ] #2 The chosen ordering is stable and user-meaningful, prioritizing collected records over wishlisted records where that distinction is displayed.
- [ ] #3 Recent activity and top-album behaviour remains otherwise unchanged.
- [ ] #4 Tests assert deterministic matching-record ordering for representative collection/wishlist combinations.
- [ ] #5 Query plans are reviewed for the changed SQL and no obvious full-scan regression is introduced.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## 1. Objective alignment

The `json_group_array(json_object(...))` calls in `ListeningStats` construct matching-record payloads for recent activity and top-album metadata without an aggregate `ORDER BY` clause. SQLite returns rows to `json_group_array()` in an arbitrary order that can change between invocations, making the JSON arrays non-deterministic.

This plan makes ordering deterministic by adding an aggregate `ORDER BY` clause to each `json_group_array(json_object(...))` fragment. The chosen ordering prioritizes collected records (purchased_at IS NOT NULL) over wishlisted records (purchased_at IS NULL), with `r.id` as a stable secondary key. This mirrors the ordering already used in the `cover_hash` correlated subquery within the same module, and matches the visual hierarchy in the UI where collected records appear first/more prominently and wishlisted records are dimmed.

The plan changes only the SQL fragments in `ListeningStats` — no schema changes, no new indexes, no migration, no API changes.

## 2. Simplicity and alternatives considered

**Chosen approach**: Add `ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id` inside each `json_group_array()` call.

**Alternatives evaluated and rejected**:

- **Order by `r.title`**: Titles are user-meaningful but don't reflect the collection/wishlist distinction. Two records with the same title (different formats) would tie-break unpredictably. Rejected because it doesn't satisfy acceptance criterion #2.
- **Order by `r.purchased_at DESC, r.id`**: Puts collected records first (since wishlisted have NULL purchased_at, which sorts last by default in SQLite). However, this doesn't guarantee all collected records appear before all wishlisted records — NULL ordering behavior depends on the SQLite `NULLS FIRST/LAST` setting. The explicit CASE expression is unambiguous. Rejected in favor of the more explicit CASE approach.
- **Order by `r.format, r.id`**: Stable but doesn't prioritize collection vs wishlist. Rejected because acceptance criterion #2 explicitly requires prioritizing collected records.
- **`ORDER BY r.id` alone**: Stable but ignores the collected/wishlisted distinction. Rejected — doesn't satisfy acceptance criterion #2.

**Why the chosen approach is the right trade-off**: It's minimal (one clause addition per fragment), uses an ordering pattern already established in the same module (the `cover_hash` subquery uses the identical `CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END, r.id`), and directly satisfies both acceptance criteria: deterministic ordering (#1) and collection-first priority (#2).

## 3. Completeness and sequencing

### Dependencies

- No step depends on external changes. The change is self-contained within `ListeningStats`.
- SQLite 3.44.0+ is required for aggregate `ORDER BY`. The project runs SQLite 3.53.1 (confirmed via `exqlite` 0.37.0).

### Steps

#### Step 1: Add ORDER BY to `tracks_with_record_info_query/0` matching_records

**What**: In `lib/music_library/listening_stats.ex`, locate the `json_group_array(json_object(...))` fragment inside `tracks_with_record_info_query/0`. Append `ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id` before the closing `)` of `json_group_array`.

**Current fragment (before the `)` of json_group_array)**:

```sql
'purchased_at', r.purchased_at, \
'cover_hash', r.cover_hash\
)) \
```

**After change**:

```sql
'purchased_at', r.purchased_at, \
'cover_hash', r.cover_hash\
) ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id) \
```

**Affects**: `recent_activity/2` and `list_tracks/1` (both call `tracks_with_record_info_query/0`). Matching records for each track row will now be deterministically ordered: collected records first, then wishlisted, subsorted by id.

**Verification**:

- Run `mix test test/music_library/listening_stats_test.exs` — existing deduplication and mixed collection/wishlist tests must still pass.
- Run `mix test test/music_library_web/live/stats_live/index_test.exs` — StatsLive scrobble activity tests must still pass.

#### Step 2: Add ORDER BY to `top_albums_attach_metadata/1` matching_records

**What**: In `lib/music_library/listening_stats.ex`, locate the `json_group_array(json_object(...))` fragment inside `top_albums_attach_metadata/1`. Apply the same `ORDER BY` clause.

**Affects**: `get_top_albums/1`, `get_top_albums_by_days/2`. Matching records for each top-album entry will be deterministically ordered.

**Verification**:

- Run `mix test test/music_library/listening_stats_test.exs` — `get_top_albums` tests in the deduplication and mixed collection/wishlist describes must still pass.
- Run `mix test test/music_library_web/live/stats_live/top_albums_test.exs` — existing tests must still pass.

#### Step 3: Add or adjust fixtures for multi-record ordering tests

**What**: The existing test fixtures in `test/music_library/listening_stats_test.exs` already cover mixed collected/wishlisted records for a release group (the "matching_records with mixed collected and wishlisted" describe). However, the tests only assert presence of both records, not their order. Add assertions that:

1. Collected records appear before wishlisted records in the `matching_records` list.
2. Within the collected group, records are ordered by `id`.
3. Within the wishlisted group, records are ordered by `id`.

The existing fixture setup in the "deduplication when multiple records share a release group" describe creates two collected records — these tests also need order assertions.

**Verification**: The new assertions must pass after Steps 1–2 are applied. Run `mix test test/music_library/listening_stats_test.exs` and confirm all tests pass.

#### Step 4: Run EXPLAIN QUERY PLAN for changed SQL

**What**: Execute `EXPLAIN QUERY PLAN` on both modified queries and compare against current plans. The `ORDER BY` inside `json_group_array` is processed on the inner correlated subquery result set, which is already bounded by the `WHERE r.musicbrainz_id = (...)` filter. Since a release group typically has 1–5 records, the sort cost is negligible.

**Verification**:

- Inside `mise run dev:sqlite-console`, run:
  ```sql
  EXPLAIN QUERY PLAN SELECT json_group_array(json_object('id', r.id, 'title', r.title, 'format', r.format, 'type', r.type, 'purchased_at', r.purchased_at, 'cover_hash', r.cover_hash) ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id) FROM records r WHERE r.musicbrainz_id = 'some-real-id';
  ```
  Confirm the plan shows no full table scan — it should use the existing index on `records.musicbrainz_id`.
- Repeat for the top-albums path.

#### Step 5: Run the full test suite

**What**: Run the complete project test suite to ensure no regressions:

```bash
mise run test
```

#### Step 6: Run pre-commit checks

**What**: Stage changes and run the pre-commit script:

```bash
git add lib/music_library/listening_stats.ex test/music_library/listening_stats_test.exs
bash scripts/dev/precommit
```

## 4. Verifiability

Each step above includes specific verification actions. Summary of all verification checkpoints:

| Step | Verification                                                                        |
| ---- | ----------------------------------------------------------------------------------- |
| 1    | `mix test test/music_library/listening_stats_test.exs` + StatsLive index tests      |
| 2    | `mix test test/music_library/listening_stats_test.exs` + StatsLive top_albums tests |
| 3    | `mix test test/music_library/listening_stats_test.exs` — new order assertions pass  |
| 4    | `EXPLAIN QUERY PLAN` shows index usage, no full scan                                |
| 5    | `mise run test` — full suite green                                                  |
| 6    | `scripts/dev/precommit` — format, credo, sobelow, tests all pass                    |

## 5. Architecture impact analysis

| Touchpoint                  | Impact                                                                                                                                                                                                                                                                                       |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ListeningStats` context    | **Changed**: two private functions (`tracks_with_record_info_query/0`, `top_albums_attach_metadata/1`) get an ORDER BY clause added to their `json_group_array` fragments. No public API changes.                                                                                            |
| `Records.Record` schema     | **Unchanged**: `parse_matching_record/1` is unaffected — it parses the same JSON object shape, just now in a deterministic order. No field additions or removals.                                                                                                                            |
| `parse_matching_records/1`  | **Unchanged**: processes the same JSON array from `json_group_array`, just now deterministically ordered.                                                                                                                                                                                    |
| `StatsLive.Index`           | **Indirectly affected**: the `recent_activity` stream and top-album components render matching records. When a release group has both collected and wishlisted variants, the order they appear in the UI dropdown/row will now be stable (collected first). No LiveView code changes needed. |
| `TopAlbums` component       | **Indirectly affected**: renders matching records via `record_components`. Same as above — order is now stable.                                                                                                                                                                              |
| `ScrobbledTracksLive.Index` | **Indirectly affected**: uses `list_tracks/1` which calls `tracks_with_record_info_query/0`. Matching record order in track rows is now deterministic.                                                                                                                                       |
| PubSub topics               | **Unchanged**: no new topics, no message format changes.                                                                                                                                                                                                                                     |
| Supervision tree            | **Unchanged**: no new processes.                                                                                                                                                                                                                                                             |
| External APIs               | **Unchanged**: no API calls in this path.                                                                                                                                                                                                                                                    |
| Database                    | **Unchanged**: no schema changes, no migrations. The `records.musicbrainz_id` index already exists and covers the WHERE clause.                                                                                                                                                              |

## 6. Performance profile

**Time complexity**: The ORDER BY operates on the result set of a correlated subquery filtered by `WHERE r.musicbrainz_id = (...)`. Each row in the outer query (tracks/top-albums) triggers one subquery execution. The subquery matches records sharing a release group — typically 1–5 rows in the vast majority of cases. Sorting 1–5 rows is O(n log n) but effectively constant-time at this scale. The cost per outer row is unchanged from the current implementation (which already does the same scan+json_group_array, just without the sort).

**Database query patterns**: No change to the query shape. Still correlated scalar subqueries bounded by the outer LIMIT. The ORDER BY is processed by SQLite's aggregate engine during `json_group_array` execution; it does not affect the outer query plan. No N+1 risk — the correlated subquery was already N queries (one per outer row), and this doesn't change that count or its cost profile.

**Memory footprint**: `json_group_array` already buffers all matching record rows into a JSON string. Adding ORDER BY doesn't change the buffer size — it only changes the order rows are fed into the accumulator. No additional memory allocation.

**Latency/throughput**: Negligible. Sorting 1–5 integers within a subquery that already does a B-tree lookup on `musicbrainz_id` is not measurable at realistic loads. The outer query's LIMIT (100 for `recent_activity`, configurable for top albums) caps the number of subquery invocations.

**Index usage**: The `WHERE r.musicbrainz_id = (...)` clause in both subqueries uses the existing index on `records.musicbrainz_id`. The ORDER BY does not interfere with this index usage — it only affects post-filter ordering.

## 7. Benchmarking requirements

**One-off verification**: Run `EXPLAIN QUERY PLAN` on both fragments before and after the change (Step 4). The plan must show the same index usage and no introduction of full-table scans. No ongoing monitoring benchmarks are needed — the change is a pure reordering of already-fetched data with no new scan or join paths.

**What to measure**:

- `EXPLAIN QUERY PLAN` output for `tracks_with_record_info_query` (pick one representative track)
- `EXPLAIN QUERY PLAN` output for `top_albums_attach_metadata` (pick one representative album)

**Threshold**: The query plan must remain identical to the current plan, with the addition of `USE TEMP B-TREE FOR ORDER BY` at the innermost subquery level (which is expected and unavoidable for any ORDER BY). No `SCAN TABLE records` (full scan) should appear.

## 8. Cost profile

No paid resources are consumed by this change. It is a pure SQL fragment modification within the existing SQLite database. No API calls, no additional compute, no storage changes.

## 9. Production infrastructure steps

**No production changes required**. The change is a pure application-code modification with no database migration, no environment variable changes, no service provisioning, no DNS changes, and no firewall rule changes. Deployment follows the standard CI/CD pipeline.

## 10. Documentation updates

| File                                          | Change                                                                                                                                                                                                                                                                                        |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/architecture.md`                        | No change needed — the architecture document describes module responsibilities and schemas at a higher level. The `ListeningStats` context description is already accurate.                                                                                                                   |
| `docs/project-conventions.md`                 | No change needed — no new convention is introduced. The SQL pattern (aggregate ORDER BY) is a standard SQLite feature, not a project-specific convention.                                                                                                                                     |
| `.agents/skills/sqlite-optimization/SKILL.md` | **Minor addition recommended**: Add a note in the "JSON Column Patterns" section documenting that `json_group_array(json_object(...))` should include an explicit `ORDER BY` clause to ensure deterministic output. This is a project convention worth documenting because it's easy to miss. |

<!-- SECTION:PLAN:END -->
