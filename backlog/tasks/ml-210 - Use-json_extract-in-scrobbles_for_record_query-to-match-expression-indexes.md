---
id: ML-210
title: Use json_extract in scrobbles_for_record_query to match expression indexes
status: Done
assignee:
  - pi-agent
created_date: "2026-06-10 10:37"
updated_date: "2026-06-13 16:55"
labels:
  - perf
dependencies: []
references:
  - lib/music_library/listening_stats.ex
  - priv/repo/migrations/20260216115654_add_scrobbled_tracks_indexes.exs
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`ListeningStats.scrobbles_for_record_query` (lib/music_library/listening_stats.ex:624-627) filters `scrobbled_tracks` with `? ->> '$.musicbrainz_id'`, `? ->> '$.title'` and `? ->> '$.name'` fragments. The expression indexes added in priv/repo/migrations/20260216115654_add_scrobbled_tracks_indexes.exs are built on `json_extract(...)`. SQLite matches expression indexes textually, so `->>` and `json_extract()` do not match and all three indexes are unusable: `play_count/1` and `get_last_listened_track/1` full-scan `scrobbled_tracks` on every record show page visit.

This violates the project's documented SQLite rule: "json_extract() must match expression index text exactly" (docs/project-conventions.md, .agents/skills/sqlite-optimization/SKILL.md).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 All three fragments in scrobbles_for_record_query use json_extract(?, '$.path') form matching the index expressions exactly
- [x] #2 EXPLAIN QUERY PLAN (via mise run dev:sqlite-console) confirms the query uses the scrobbled_tracks expression indexes instead of a full scan
- [x] #3 Tests cover play_count/1 and get_last_listened_track/1 returning correct results for records matched by release id and by title+artist fallback

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Capture a baseline before any code changes: inspect the current generated SQL for `ListeningStats.play_count/1` / `get_last_listened_track/1`, run `EXPLAIN QUERY PLAN`, and benchmark representative query timing against the current `->>` predicates.
2. Rewrite the three fragments in `scrobbles_for_record_query` (`lib/music_library/listening_stats.ex`) from `? ->> '$.path'` to `json_extract(?, '$.path')`, matching the expression indexes in `priv/repo/migrations/20260216115654_add_scrobbled_tracks_indexes.exs` character-for-character.
3. Capture the generated SQL after the change, run `EXPLAIN QUERY PLAN` via `mise run dev:sqlite-console`, and benchmark the same representative calls to confirm the expression indexes are used and timing improves or at least does not regress.
4. Check `test/music_library/listening_stats_test.exs` coverage for `play_count/1` and `get_last_listened_track/1`; add cases for (a) match via album MusicBrainz release id in `release_ids` and (b) fallback match via album title + artist name.
5. Run the relevant listening stats tests after each implementation loop, check off acceptance criteria when met, then run the project precommit checks before finalization.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Pre-flight complete: read docs/architecture.md, docs/project-conventions.md, Backlog execution/finalization guidance, task plan, and relevant sqlite-optimization/testing/query-reporter skills. User additionally requested before/after benchmarking, so the implementation plan presented for approval will include baseline and post-change benchmark checkpoints before code changes are made.

Baseline captured before code changes using record `565b07c8-b679-40f3-8b37-69f2ec32c5ba` (`Night` by Gazpacho) against dev DB with 106,019 `scrobbled_tracks`. QueryReporter captured current SQL using `album ->> '$.musicbrainz_id'`, `album ->> '$.title'`, and `artist ->> '$.name'`. `mise run dev:sqlite-console` baseline `EXPLAIN QUERY PLAN` showed `SELECT count(*) ...` as `SCAN s0`; the last-listened query scanned via `scrobbled_tracks_scrobbled_at_uts_title_index` for ordering, not the JSON expression indexes. Baseline timing over 30 runs after 5 warmups: `play_count/1` median 43.621 ms (avg 44.449 ms), `get_last_listened_track/1` median 1.695 ms (avg 1.688 ms).

Implemented the fragment rewrite in `lib/music_library/listening_stats.ex`: all three `scrobbles_for_record_query/1` JSON predicates now use `json_extract(?, '$.musicbrainz_id')`, `json_extract(?, '$.title')`, and `json_extract(?, '$.name')`. Ran `mix test test/music_library/listening_stats_test.exs --max-failures 5`: 53 passed. AC #1 is satisfied.

Post-change QueryReporter capture confirmed generated SQL now uses `json_extract(s0."album", '$.musicbrainz_id')`, `json_extract(s0."album", '$.title')`, and `json_extract(s0."artist", '$.name')`. `mise run dev:sqlite-console` `EXPLAIN QUERY PLAN` now shows `MULTI-INDEX OR` with `SEARCH s0 USING INDEX scrobbled_tracks_album_musicbrainz_id_index` and `SEARCH s0 USING INDEX scrobbled_tracks_album_title_artist_name_index` for both the count and last-listened queries (last-listened additionally uses a temp B-tree for ordering). Post-change timing over the same 30-run benchmark: `play_count/1` median 0.326 ms (avg 0.331 ms), `get_last_listened_track/1` median 0.436 ms (avg 0.448 ms). Compared with baseline, `play_count/1` improved from 43.621 ms median and `get_last_listened_track/1` from 1.695 ms median. AC #2 is satisfied.

Added explicit regression coverage in `test/music_library/listening_stats_test.exs` for both matching paths. `get_last_listened_track/1` now has a release-id match test where title/artist differ and a title+artist fallback test. `play_count/1` now has a release-id count test where title/artist differ and a title+artist fallback test. Ran `mix test test/music_library/listening_stats_test.exs --max-failures 5`: 55 passed. AC #3 is satisfied.

Validation checkpoint: `mise run dev:precommit` initially found only Backlog markdown formatting drift after the task-note updates. Ran Prettier on the Backlog task file, then reran `mise run dev:precommit` successfully. Passing checks included shellcheck, Credo strict, Sobelow, gettext up-to-date, mix format check, all four partitioned test suites (344 + 216 + 292 + 325 Elixir tests/doctests), unused deps, asset/docs/backlog Prettier checks, Presto pytest (36 passed), and Docker image validation.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Implemented the scrobble record lookup optimization by changing `ListeningStats.scrobbles_for_record_query/1` to use `json_extract(?, '$.musicbrainz_id')`, `json_extract(?, '$.title')`, and `json_extract(?, '$.name')` so SQLite can match the existing `scrobbled_tracks` expression indexes.

Added regression coverage for both public callers and both matching paths: `play_count/1` and `get_last_listened_track/1` now cover release-id matching and title+artist fallback matching.

Benchmarks on the dev DB record `Night` by Gazpacho (106,019 scrobbles, 30 runs after warmup) improved from `play_count/1` median 43.621 ms to 0.326 ms and `get_last_listened_track/1` median 1.695 ms to 0.436 ms. `EXPLAIN QUERY PLAN` changed from a full scan for the count query to `MULTI-INDEX OR` using `scrobbled_tracks_album_musicbrainz_id_index` and `scrobbled_tracks_album_title_artist_name_index`.

Tests/checks run:

- `mix test test/music_library/listening_stats_test.exs --max-failures 5` (55 passed)
- `mise run dev:sqlite-console` with `EXPLAIN QUERY PLAN`
- `mise run dev:precommit` (passed: shellcheck, Credo strict, Sobelow, gettext, format, full partitioned test suite, deps unlock, Prettier, Presto tests, Docker image validation)

Risks/follow-ups: none identified.

<!-- SECTION:FINAL_SUMMARY:END -->
