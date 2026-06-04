---
id: ML-206
title: Evaluate JSONB storage for hot JSON fields
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:05"
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
  - docs
  - priv/repo/migrations
  - config/runtime.exs
  - config/dev.exs
  - config/test.exs
  - lib/music_library
priority: low
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Run a focused spike on whether SQLite JSONB storage is worth adopting for hot JSON fields. SQLite 3.45+ supports JSONB, and this project’s current `ecto_sqlite3` version documents `:map_type` and `:array_type` options for binary JSONB storage. Local estimates showed potential space savings on `scrobbled_tracks` and `records.musicbrainz_data`, but migration, Ecto compatibility, expression indexes, triggers, and operational tooling need verification before any production change.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 The spike documents how `ecto_sqlite3` JSONB configuration works for `:map` and `:array` fields in this project.
- [ ] #2 Representative space and query-performance measurements compare current text JSON with JSONB for `scrobbled_tracks`, record metadata, and artist metadata.
- [ ] #3 The assessment covers compatibility with JSON expression indexes, FTS/search triggers, Ecto schemas, tests, backups, and production rollback.
- [ ] #4 A clear go/no-go recommendation is recorded with risks and migration strategy if adoption is recommended.
- [ ] #5 Follow-up implementation tasks are created only if the recommendation is to proceed.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Review current `ecto_sqlite3` JSONB support (`:map_type`, `:array_type`) and how it interacts with loaders/dumpers in this project.
2. Build a local benchmark or repeatable SQL script comparing text JSON and JSONB for representative fields and queries.
3. Measure storage deltas using `dbstat` and query deltas for common `json_extract`, `json_each`, insert/update, and indexed lookup paths.
4. Evaluate migration and rollback strategies, including expression indexes, FTS triggers, tests, backups, and compatibility with external SQLite tooling.
5. Record findings in project/backlog documentation with a clear go/no-go recommendation.
6. If adoption is recommended, create scoped implementation tasks for migration/config changes rather than implementing them inside the spike.
<!-- SECTION:PLAN:END -->
