---
id: ML-202
title: Make JSON aggregate ordering deterministic
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:05"
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

1. Inspect each `json_group_array(json_object(...))` fragment in `ListeningStats` and identify the record ordering users should see.
2. Update the aggregate calls to include SQLite aggregate `ORDER BY` clauses while preserving existing selected fields and parsing behaviour.
3. Add or adjust fixtures so tests cover multiple matching records in both collection and wishlist states.
4. Add assertions that matching-record arrays are deterministic for recent activity and top-album metadata.
5. Run `EXPLAIN QUERY PLAN` for the changed SQL and compare against current plans to avoid introducing obvious regressions.
6. Run the relevant ListeningStats and LiveView tests.
<!-- SECTION:PLAN:END -->
