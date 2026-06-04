---
id: ML-205
title: Use SQLite 3.46+ optimize behaviour
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
  - lib/music_library/worker/repo_optimize.ex
  - test/music_library/maintenance_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
documentation:
  - "https://sqlite.org/changes.html#version_3_46_0"
  - "https://sqlite.org/lang_analyze.html#pragopt"
  - docs/project-conventions.md
  - docs/architecture.md
modified_files:
  - lib/music_library/repo.ex
  - lib/music_library/maintenance.ex
  - lib/music_library/worker/repo_optimize.ex
  - test/music_library/maintenance_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
  - docs/architecture.md
  - docs/project-conventions.md
priority: medium
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Update database maintenance to take advantage of the enhanced PRAGMA optimize behaviour available in the current SQLite runtime (verified as 3.53.2). The app currently runs plain `PRAGMA optimize` through `MusicLibrary.Repo.optimize/0`; SQLite 3.46+ recommends `PRAGMA optimize=0x10002` for fresh/long-lived connections because it examines all tables while automatically limiting analysis work. Consider whether the same maintenance path should cover the background and telemetry repos, not only the main app repo.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Maintenance optimize uses the SQLite 3.46+ recommended optimize mode where appropriate, with the bitmask documented in code or docs.
- [ ] #2 The implementation explicitly decides whether to optimize MusicLibrary.BackgroundRepo and MusicLibrary.TelemetryRepo as well as MusicLibrary.Repo, and documents the reason.
- [ ] #3 Existing maintenance UI and worker behaviour still report success and failure clearly.
- [ ] #4 Tests cover the updated optimize behaviour without relying on production data.
- [ ] #5 Relevant project documentation is updated if the maintenance behaviour changes.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Re-read SQLite PRAGMA optimize guidance and confirm the bitmask semantics against the installed SQLite version.
2. Inspect `MusicLibrary.Repo.optimize/0`, `MusicLibrary.Maintenance.optimize/0`, `MusicLibrary.Worker.RepoOptimize`, and MaintenanceLive event handling to identify all optimize entry points.
3. Update the optimize helper(s) to use the recommended SQLite 3.46+ mode where appropriate, documenting why `0x10002` or plain `PRAGMA optimize` is chosen.
4. Decide whether BackgroundRepo and TelemetryRepo should be optimized from the same maintenance action; implement or document the exclusion.
5. Update tests for the context, worker, and UI success/error paths.
6. Update architecture/project-convention docs if the operational behaviour changes, then run the relevant test subset.
<!-- SECTION:PLAN:END -->
