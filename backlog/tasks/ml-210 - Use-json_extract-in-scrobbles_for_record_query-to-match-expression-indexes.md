---
id: ML-210
title: Use json_extract in scrobbles_for_record_query to match expression indexes
status: To Do
assignee: []
created_date: "2026-06-10 10:37"
updated_date: "2026-06-10 10:55"
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

- [ ] #1 All three fragments in scrobbles_for_record_query use json_extract(?, '$.path') form matching the index expressions exactly
- [ ] #2 EXPLAIN QUERY PLAN (via mise run dev:sqlite-console) confirms the query uses the scrobbled_tracks expression indexes instead of a full scan
- [ ] #3 Tests cover play_count/1 and get_last_listened_track/1 returning correct results for records matched by release id and by title+artist fallback
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Rewrite the three fragments in scrobbles_for_record_query (lib/music_library/listening_stats.ex:624-627) from `? ->> '$.path'` to `json_extract(?, '$.path')`, matching the index expressions in 20260216115654_add_scrobbled_tracks_indexes.exs character-for-character.
2. Capture the generated SQL (QueryReporter or Repo.to_sql) and run EXPLAIN QUERY PLAN in `mise run dev:sqlite-console`; confirm the scrobbled_tracks expression indexes are used.
3. Check test/music_library/listening_stats_test.exs coverage for play_count/1 and get_last_listened_track/1; add cases for (a) match via album musicbrainz_id in release_ids and (b) fallback match via album title + artist name.
4. Run the listening stats tests, then precommit.
<!-- SECTION:PLAN:END -->
