---
id: ML-207
title: Add expression-index reindex maintenance action
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:05"
labels:
  - sqlite
  - maintenance
dependencies: []
references:
  - lib/music_library/repo.ex
  - lib/music_library/maintenance.ex
  - lib/music_library_web/live/maintenance_live/index.ex
documentation:
  - "https://sqlite.org/changes.html#version_3_53_0"
  - "https://sqlite.org/lang_reindex.html"
  - "https://sqlite.org/staleexpridx.html"
  - docs/project-conventions.md
  - docs/architecture.md
modified_files:
  - lib/music_library/repo.ex
  - lib/music_library/maintenance.ex
  - lib/music_library_web/live/maintenance_live/index.ex
  - test/music_library/maintenance_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
  - docs/architecture.md
priority: medium
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

SQLite 3.53 adds `REINDEX EXPRESSIONS`, which rebuilds expression indexes without rebuilding every ordinary index. This app has expression indexes such as `assets_content_size_index` and several `scrobbled_tracks` JSON extraction indexes. Add an authenticated maintenance path for rare repair/upgrade scenarios where expression indexes should be refreshed after SQLite or SQL-function changes.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 A maintenance operation can run `REINDEX EXPRESSIONS` against the main application database outside an Ecto transaction.
- [ ] #2 The Maintenance UI exposes the action with clear copy explaining that it is for rare expression-index repair/upgrade scenarios.
- [ ] #3 Success and failure states are reported clearly to the user and logged appropriately on failure.
- [ ] #4 Tests cover the context function and Maintenance UI event path.
- [ ] #5 Documentation records when to use the action and why it is distinct from full REINDEX or PRAGMA optimize.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add a repository/context function that runs `REINDEX EXPRESSIONS` outside transactions and returns the existing `{:ok, result}` / `{:error, reason}` shape.
2. Wire the operation into the authenticated Maintenance UI with copy explaining the rare repair/upgrade use case.
3. Add success and error handling consistent with existing VACUUM/optimize maintenance actions.
4. Add tests for the context function and MaintenanceLive event, including failure handling if practical.
5. Document when to use expression-index reindexing and how it differs from full REINDEX, PRAGMA optimize, and VACUUM.
6. Run relevant maintenance/UI tests.
<!-- SECTION:PLAN:END -->
