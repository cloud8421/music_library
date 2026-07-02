---
id: ML-203
title: Show WAL checkpoint diagnostics in maintenance
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:05"
labels:
  - sqlite
  - maintenance
  - observability
dependencies: []
references:
  - lib/music_library/maintenance.ex
  - lib/music_library_web/live/maintenance_live/index.ex
  - docs/production-infrastructure.md
documentation:
  - "https://sqlite.org/changes.html#version_3_51_0"
  - "https://sqlite.org/pragma.html#pragma_wal_checkpoint"
  - docs/production-infrastructure.md
  - docs/architecture.md
modified_files:
  - lib/music_library/maintenance.ex
  - lib/music_library_web/live/maintenance_live/index.ex
  - test/music_library/maintenance_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
  - docs/production-infrastructure.md
  - docs/architecture.md
priority: medium
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

SQLite 3.51 added `PRAGMA wal_checkpoint=NOOP`, which reports WAL checkpoint state without performing a checkpoint. Add maintenance diagnostics so the app can show WAL backlog information safely for operational debugging without changing database state.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Maintenance diagnostics display WAL checkpoint state using `PRAGMA wal_checkpoint=NOOP` without triggering a checkpoint.
- [ ] #2 The displayed data includes the SQLite result fields `busy`, `log`, and `checkpointed` with labels understandable to an operator.
- [ ] #3 Diagnostics cover the relevant SQLite repos or explicitly document why only a subset is shown.
- [ ] #4 Errors from any repo are handled without crashing the maintenance page.
- [ ] #5 Tests cover successful and failing diagnostic paths.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add a context-level diagnostic function that runs `PRAGMA wal_checkpoint=NOOP` and normalizes `busy`, `log`, and `checkpointed` results.
2. Decide which repos to inspect and model partial failures so one repo error does not crash the whole maintenance page.
3. Render the diagnostics in MaintenanceLive with operator-friendly labels and a short explanation that NOOP does not checkpoint.
4. Add tests for successful diagnostics, partial/error handling, and UI rendering.
5. Update production infrastructure or architecture docs with the diagnostic meaning and operational caveats.
6. Run relevant maintenance/UI tests.

<!-- SECTION:PLAN:END -->
