---
id: ML-202
title: Make JSON aggregate ordering deterministic
status: Done
assignee:
  - pi
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 05:35"
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
  - .agents/skills/sqlite-optimization/SKILL.md
priority: medium
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Use SQLite aggregate ORDER BY support to make JSON arrays built by `json_group_array(json_object(...))` deterministic in listening statistics. Current matching-record payloads are constructed in SQL without an aggregate ordering clause, so record order can vary. Preserve existing semantics while making the order stable for recent activity and top-album metadata.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 All SQL `json_group_array(json_object(...))` matching-record payloads in ListeningStats use an explicit aggregate ORDER BY clause.
- [x] #2 The chosen ordering is stable and user-meaningful, prioritizing collected records over wishlisted records where that distinction is displayed.
- [x] #3 Recent activity and top-album behaviour remains otherwise unchanged.
- [x] #4 Tests assert deterministic matching-record ordering for representative collection/wishlist combinations.
- [x] #5 Query plans are reviewed for the changed SQL and no obvious full-scan regression is introduced.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## 1. Objective and scope

Make every `json_group_array(json_object(...))` matching-record payload in `MusicLibrary.ListeningStats` deterministic by using SQLite aggregate `ORDER BY` support.

Current affected payloads:

1. `tracks_with_record_info_query/0` — used by `list_tracks/1` and `recent_activity/2`.
2. `top_albums_attach_metadata/1` — used by `get_top_albums/1` and `get_top_albums_by_days/2`.

The change is intentionally narrow:

- No schema changes.
- No migrations or new indexes.
- No public API shape changes.
- No LiveView/component changes.
- No production infrastructure changes.

The output JSON object shape remains unchanged. Only the array order becomes deterministic.

## 2. Chosen ordering

Use this aggregate ordering in both `json_group_array(json_object(...))` fragments:

```sql
ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id
```

Ordering semantics:

1. Collected records (`purchased_at IS NOT NULL`) appear before wishlisted records (`purchased_at IS NULL`). This is the user-meaningful part of the ordering and matches how the UI distinguishes collected and wishlisted records.
2. `r.id` provides a stable deterministic tie-breaker within each group. There is no existing domain-level preference for ordering multiple collected copies or multiple wishlisted copies of the same release group, so `id` avoids inventing new UI semantics.

This matches the existing `cover_hash` correlated subqueries in the same module, which already prioritize collected records first and then use `r.id`.

## 3. Simplicity and alternatives considered

**Chosen approach**: add the aggregate `ORDER BY` clause directly inside each `json_group_array(...)` call.

Alternatives considered:

- **Application-level sorting after JSON decode**: rejected because the SQL payload itself would remain non-deterministic and every caller/parser path would need to preserve the same ordering rule manually. The task specifically targets SQLite aggregate ordering.
- **Wrap an ordered subquery around the aggregate**: rejected because it is more verbose and was only necessary before SQLite 3.44.0. The project runtime supports aggregate `ORDER BY` directly.
- **Order by `r.title`, `r.format`, or `r.type` before `r.id`**: rejected because these introduce new ordering semantics not currently expressed elsewhere. Format/type ordering would be alphabetical rather than a product decision.
- **Order by `r.purchased_at DESC, r.id`**: rejected because it changes the secondary order of collected records to purchase recency. The objective is deterministic matching-record order, not recency ranking. The explicit `CASE` expression also documents the collection-vs-wishlist priority clearly.
- **Order by `r.id` only**: rejected because it ignores the collected/wishlisted distinction required by acceptance criterion #2.

The chosen approach is the smallest implementation that satisfies determinism and the collection-first display priority.

## 4. Prerequisites and compatibility

SQLite aggregate `ORDER BY` is available from SQLite 3.44.0. The current project runtime reports SQLite 3.53.2 through `exqlite` 0.37.0, so the syntax is supported locally.

Verification command:

```sql
SELECT sqlite_version();
```

If a future environment reports SQLite < 3.44.0, stop and replace this plan with the ordered-subquery fallback rather than implementing direct aggregate `ORDER BY`.

## 5. Implementation steps

### Step 1: Confirm affected SQL fragments

Search before editing:

```bash
rg -n "json_group_array\(json_object|matching_records" lib/music_library/listening_stats.ex
```

Expected affected fragments are the two matching-record subqueries in:

- `tracks_with_record_info_query/0`
- `top_albums_attach_metadata/1`

Do not change unrelated JSON aggregation if new unrelated matches appear.

### Step 2: Update `tracks_with_record_info_query/0`

In `lib/music_library/listening_stats.ex`, update the matching-record aggregate from:

```sql
'cover_hash', r.cover_hash\
)) \
```

to:

```sql
'cover_hash', r.cover_hash\
) ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id) \
```

Affected public paths:

- `ListeningStats.list_tracks/1`
- `ListeningStats.recent_activity/2`
- `ScrobbledTracksLive.Index`
- `StatsLive.Index` recent activity sections

### Step 3: Update `top_albums_attach_metadata/1`

Apply the same aggregate `ORDER BY` clause to the matching-record aggregate inside `top_albums_attach_metadata/1`.

Affected public paths:

- `ListeningStats.get_top_albums/1`
- `ListeningStats.get_top_albums_by_days/2`
- `StatsLive.TopAlbums`
- `StatsLive.Index` top-album sections

### Step 4: Strengthen deterministic-order tests

Update `test/music_library/listening_stats_test.exs` with representative ordering assertions.

Use a fixture setup with at least four records sharing the same release group:

- two collected records (`purchased_at` set)
- two wishlisted records (`purchased_at: nil`)

Create at least one scrobbled track whose album MusicBrainz release ID maps to that shared release group.

Expected order helper:

```elixir
expected_ids =
  collected_records
  |> Enum.map(& &1.id)
  |> Enum.sort()
  |> Kernel.++(
    wishlisted_records
    |> Enum.map(& &1.id)
    |> Enum.sort()
  )
```

Assert `Enum.map(result.matching_records, & &1.id) == expected_ids` for:

1. `ListeningStats.list_tracks/1`
2. `ListeningStats.recent_activity/2`
3. `ListeningStats.get_top_albums/1`

Keep the existing presence/shape assertions for `:id`, `:title`, `:format`, `:type`, `:purchased_at`, and `:cover_hash` so behaviour remains otherwise covered.

### Step 5: Review query plans with the real lookup path

Run `EXPLAIN QUERY PLAN` against the actual changed inner lookup shape, not just a simplified `records` query.

Pick a real release ID:

```sql
SELECT release_id FROM record_releases LIMIT 1;
```

Then run:

```sql
EXPLAIN QUERY PLAN
SELECT json_group_array(
  json_object(
    'id', r.id,
    'title', r.title,
    'format', r.format,
    'type', r.type,
    'purchased_at', r.purchased_at,
    'cover_hash', r.cover_hash
  ) ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id
)
FROM records r
WHERE r.musicbrainz_id = (
  SELECT r2.musicbrainz_id
  FROM records r2
  INNER JOIN record_releases rr ON rr.record_id = r2.id
  WHERE rr.release_id = '<real-release-id>'
  LIMIT 1
);
```

Expected plan characteristics:

- `SEARCH rr USING INDEX record_releases_release_id_index (release_id=?)`
- `SEARCH r2 USING INDEX sqlite_autoindex_records_1 (id=?)` or equivalent primary-key lookup
- `SEARCH r USING INDEX records_musicbrainz_id_index (musicbrainz_id=?)`
- `USE TEMP B-TREE FOR json_group_array(ORDER BY)` is expected and acceptable
- no full scan of `records` for the matching-record lookup

Repeat the same check after the final SQL is in place. The top-albums path uses the same inner release-ID lookup shape, so this representative plan is sufficient for the changed aggregate.

### Step 6: Update SQLite optimization documentation

Update `.agents/skills/sqlite-optimization/SKILL.md` under `JSON Column Patterns` with a short note that JSON aggregates whose output order is user-visible or test-relevant must include an explicit aggregate `ORDER BY` clause.

Include a minimal example similar to:

```sql
json_group_array(
  json_object('id', r.id, 'title', r.title)
  ORDER BY r.title, r.id
)
```

Mention that SQLite may report `USE TEMP B-TREE FOR json_group_array(ORDER BY)` and that this is expected for small bounded aggregate groups.

No `docs/architecture.md` update is needed because this change does not add, remove, or restructure modules, schemas, contexts, workers, routes, or external integrations.

### Step 7: Run focused tests

Run:

```bash
mix test test/music_library/listening_stats_test.exs
mix test test/music_library_web/live/stats_live/index_test.exs
mix test test/music_library_web/live/stats_live/top_albums_test.exs
mix test test/music_library_web/live/scrobbled_tracks_live/index_test.exs
```

### Step 8: Run full verification

Run the full test suite:

```bash
mise run test
```

Stage the relevant files and run the conditional pre-commit checks:

```bash
git add lib/music_library/listening_stats.ex \
  test/music_library/listening_stats_test.exs \
  .agents/skills/sqlite-optimization/SKILL.md
mise run dev:precommit
```

## 6. Architecture impact analysis

| Touchpoint                               | Impact                                                                                                                  |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ListeningStats` context                 | Two private SQL fragments gain aggregate ordering. Public return shapes stay the same.                                  |
| `Records.Record.parse_matching_record/1` | Unchanged. It parses the same JSON object shape.                                                                        |
| `StatsLive.Index`                        | Indirect display-only impact: matching-record dropdown/order is now stable, collected first.                            |
| `StatsLive.TopAlbums`                    | Indirect display-only impact: matching-record dropdown/order is now stable, collected first.                            |
| `ScrobbledTracksLive.Index`              | Indirect display-only impact through `list_tracks/1`.                                                                   |
| Database schema/indexes                  | Unchanged. Existing `record_releases.release_id` and `records.musicbrainz_id` indexes remain the relevant access paths. |
| Supervision tree/PubSub/external APIs    | Unchanged.                                                                                                              |
| Developer documentation                  | `.agents/skills/sqlite-optimization/SKILL.md` gains a JSON aggregate ordering convention.                               |

There is no significant architecture variation. The implementation stays inside the existing `ListeningStats` SQL-enrichment pattern.

## 7. Performance profile

The changed aggregate executes inside correlated scalar subqueries that are already bounded by the outer result limits and by release-group membership.

Expected cost:

- Per matching-record aggregate: `O(k log k)` for sorting `k` records sharing a release group.
- In normal data, `k` is expected to be small, typically 1–5 physical records for a release group.
- The number of aggregate executions is unchanged: one per outer row already returned by the existing query.
- The lookup path is unchanged and should continue to use `record_releases_release_id_index` and `records_musicbrainz_id_index`.

SQLite may allocate a temporary sorter/B-tree for the aggregate `ORDER BY`; `EXPLAIN QUERY PLAN` may show `USE TEMP B-TREE FOR json_group_array(ORDER BY)`. That is expected. The temporary memory is proportional to `k`, not to the full `records` table.

No N+1 regression is introduced because the correlated subqueries already existed. The change only orders the small result set that was already being aggregated.

## 8. Benchmarking requirements

No recurring benchmark is required. This is a deterministic-ordering change on a small bounded aggregate group.

Required one-off verification:

- Run `EXPLAIN QUERY PLAN` for the changed inner lookup shape.
- Confirm index usage remains intact.
- Confirm any temporary B-tree is only for `json_group_array(ORDER BY)`.
- Confirm there is no full `records` scan in the matching-record lookup.

If query plans unexpectedly show full scans of `records` or `record_releases`, stop and investigate before proceeding. Do not add indexes unless the plan review proves they are needed.

## 9. Cost profile

No paid resources are required. The change performs no external API calls and adds no storage, service, or infrastructure dependency.

## 10. Production infrastructure steps

No manual production infrastructure steps are required.

Deployment uses the existing application deployment path. There are no new environment variables, migrations, provisioned services, secrets, DNS changes, or backup changes.

## 11. Documentation updates

Required:

- Update `.agents/skills/sqlite-optimization/SKILL.md` with the deterministic JSON aggregate ordering convention.

Not required:

- `docs/architecture.md` — no architecture boundary changes.
- `docs/project-conventions.md` — it already delegates database-specific conventions to the SQLite optimization skill.
- `docs/production-infrastructure.md` — no infrastructure change.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Step 1: Confirmed exactly two json_group_array(json_object(...)) fragments in listening_stats.ex

Step 2-3: Added aggregate ORDER BY (CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id) to both fragments

Step 4: Added 3 deterministic ordering tests (list_tracks, recent_activity, get_top_albums) with 2 collected + 2 wishlisted records sharing a release group

Step 5: EXPLAIN QUERY PLAN confirmed no full-scan regression. Index usage intact.

All 53 listening_stats_test.exs tests pass.

Step 6: Added json_group_array() aggregate ORDER BY convention to sqlite-optimization SKILL.md

Step 7: All 37 stats/scrobbled_tracks LiveView tests pass

Step 8: Full test suite passed — 1151 tests across 4 partitions, 0 failures

Task finalized: all AC checked, tests pass, final summary written

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added SQLite aggregate ORDER BY to both json_group_array(json_object(...)) matching-record payloads in MusicLibrary.ListeningStats, using ordering `(CASE WHEN r.purchased_at IS NOT NULL THEN 0 ELSE 1 END), r.id` to put collected records before wishlisted records, with id as a stable tiebreaker.

## What changed

**lib/music_library/listening_stats.ex** — two private SQL fragments:

- `tracks_with_record_info_query/0` (line ~400): matching_records json_group_array now includes ORDER BY clause
- `top_albums_attach_metadata/1` (line ~507): matching_records json_group_array now includes ORDER BY clause

**test/music_library/listening_stats_test.exs** — new "matching_records deterministic ordering" describe block with 3 tests asserting collected-first id-ordered matching_records for list_tracks/1, recent_activity/2, and get_top_albums/1.

**.agents/skills/sqlite-optimization/SKILL.md** — added json_group_array() aggregate ORDER BY convention under JSON Column Patterns.

## Tests run

- listening_stats_test.exs: 53 passed
- stats_live/index_test.exs: passed
- stats_live/top_albums_test.exs: passed
- scrobbled_tracks_live/index_test.exs: passed
- Full suite (mise run test): 1151 passed, 0 failures

## Risks and follow-ups

No risks identified. The change is narrow — only adds an ORDER BY clause inside existing correlated subquery aggregates. No schema, migration, or public API changes. Index usage confirmed intact via EXPLAIN QUERY PLAN. No follow-up work needed.

<!-- SECTION:FINAL_SUMMARY:END -->
