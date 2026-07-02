---
id: ML-206
title: Evaluate JSONB storage for hot JSON fields
status: Done
assignee:
  - pi
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:27"
labels:
  - sqlite
  - spike
  - database
dependencies: []
references:
  - config/runtime.exs
  - lib/music_library/listening_stats.ex
  - lib/music_library/records/record.ex
  - lib/music_library/collection/enrichment.ex
  - priv/repo/migrations/20260216115654_add_scrobbled_tracks_indexes.exs
documentation:
  - "https://sqlite.org/changes.html#version_3_45_0"
  - "https://sqlite.org/json1.html#jsonbx"
  - "https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html"
  - docs/project-conventions.md
  - docs/architecture.md
modified_files:
  - docs/sqlite-jsonb-spike.md
priority: low
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Run a focused spike on whether SQLite JSONB storage is worth adopting for hot JSON fields. SQLite 3.45+ supports JSONB, and this project’s current `ecto_sqlite3` version documents `:map_type` and `:array_type` options for binary JSONB storage. Local estimates showed potential space savings on `scrobbled_tracks` and `records.musicbrainz_data`, but migration, Ecto compatibility, expression indexes, triggers, and operational tooling need verification before any production change.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The spike documents how `ecto_sqlite3` JSONB configuration works for `:map` and `:array` fields in this project.
- [x] #2 Representative space and query-performance measurements compare current text JSON with JSONB for `scrobbled_tracks`, record metadata, and artist metadata.
- [x] #3 The assessment covers compatibility with JSON expression indexes, FTS/search triggers, Ecto schemas, tests, backups, and production rollback.
- [x] #4 A clear go/no-go recommendation is recorded with risks and migration strategy if adoption is recommended.
- [x] #5 Follow-up implementation tasks are created only if the recommendation is to proceed.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

Approved approach (confirmed by user 2026-06-04):

1. Review current JSON/map/array usage in schemas, repo config, migrations, and hot query paths for `scrobbled_tracks`, `records.musicbrainz_data`, and `artist_infos`.
2. Verify current `ecto_sqlite3` JSONB support, especially `:map_type` and `:array_type`, including loader/dumper behavior and configuration scope in this project.
3. Build or run a repeatable local benchmark/script comparing text JSON with SQLite JSONB for representative hot JSON fields.
4. Measure storage and query behavior for `json_extract`, `json_each`, indexed lookups, insert/update paths, and representative record/artist/scrobble metadata access.
5. Assess compatibility with JSON expression indexes, FTS/search triggers, Ecto schemas, tests, backups, production rollout, and rollback.
6. Record findings in project/backlog documentation with a clear go/no-go recommendation, risks, and migration strategy if adoption is recommended.
7. If the recommendation is to proceed, stop and ask before creating scoped follow-up implementation tasks; do not implement production JSONB adoption inside this spike.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Pre-flight started/completed: read docs/architecture.md and docs/project-conventions.md, reviewed task plan/acceptance criteria/references, and loaded sqlite-optimization, testing, and update-documentation skills.

User approved the proposed ML-206 execution plan. Recorded the approved plan before implementation work.

Completed local JSONB investigation and benchmark on the dev database copy. Key finding: SQLite JSONB itself shows table-size savings and faster unindexed JSON scans, but current `ecto_sqlite3` v0.24.0 loader/dumper behavior in this project does not load true JSONB blobs (`Codec.json_decode/1` returns `:error` for JSONB), and `json_set` on JSONB columns converts values back to TEXT unless changed to `jsonb_set`. Preparing documentation with measurements and no-go recommendation.

Added `docs/sqlite-jsonb-spike.md` with the approved spike write-up, including `ecto_sqlite3` configuration behavior, local benchmark measurements, compatibility assessment, no-go recommendation, and migration strategy if revisited. Verification: `prettier --check docs/sqlite-jsonb-spike.md` passed; `mise run test` passed all four partitions (343, 300, 275, and 230 tests/doctests respectively). No follow-up tasks were created because the recommendation is no-go.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

- Added `docs/sqlite-jsonb-spike.md` documenting the focused SQLite JSONB spike for hot JSON fields.
- Captured how `ecto_sqlite3` v0.24.0 handles `:map_type` and `:array_type` in this project, including the key loader/dumper limitation with true SQLite JSONB blobs.
- Recorded representative storage and query-performance measurements for `scrobbled_tracks`, `records`, and `artist_infos` using local text JSON vs JSONB copies.
- Assessed compatibility with JSON expression indexes, `json_each`, trigger-maintained tables, FTS/search triggers, Ecto schemas, tests, backups, and rollback.

## Recommendation

No-go for production JSONB adoption now. SQLite JSONB showed useful storage savings and faster unindexed JSON scans, but current Ecto round-trip support is not safe for true JSONB blobs. No follow-up implementation tasks were created because the recommendation is no-go.

## Verification

- `prettier --check docs/sqlite-jsonb-spike.md`
- `mise run test` — all four partitions passed: 343, 300, 275, and 230 tests/doctests.

## Risks / follow-ups

- Revisit only if upstream `ecto_sqlite3` gains proven JSONB round-trip support or the project intentionally implements and tests a local adapter/custom-type approach.
- Any future adoption must handle `json_set` → `jsonb_set`, FTS mirror text compatibility, table rebuilds, expression-index verification, and rollback via `json(column)`. The spike document records the migration strategy.

<!-- SECTION:FINAL_SUMMARY:END -->
