---
id: ML-194
title: Add selective low-priority smoke coverage
status: Done
assignee: []
created_date: "2026-05-20 17:19"
updated_date: "2026-05-21 10:15"
labels:
  - testing
  - coverage
dependencies: []
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - docs/production-infrastructure.md
  - .agents/skills/testing/SKILL.md
  - .agents/skills/oban-worker/SKILL.md
  - .agents/skills/ui-framework/SKILL.md
modified_files:
  - test/music_library/worker/bulk_cron_workers_test.exs
  - test/music_library_web/browser_pipeline_test.exs
  - test/music_library_web/hooks/get_timezone_test.exs
  - test/music_library_web/hooks/static_assets_test.exs
priority: low
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add only low-cost tests for low-coverage wiring where there is a real regression signal. This task should not chase percentages with brittle route enumeration, supervision-shape assertions, or Phoenix framework behavior. Focus on thin bulk worker delegation, timezone/static-asset hook assignment if practical, and browser CSP/header behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Bulk cron worker smoke tests verify each all-record/all-artist worker delegates to the corresponding batch flow and enqueues the expected downstream jobs for representative records or artist infos.
- [x] #2 The bulk worker tests avoid duplicating full single-item worker API refresh behavior that is already covered elsewhere.
- [x] #3 A browser pipeline test asserts the Content-Security-Policy header includes the app-specific image, worker, connect, frame-ancestor, and base-uri directives that matter for current features.
- [x] #4 GetTimezone hook coverage verifies a provided connect-param timezone is assigned and missing connect params fall back to MusicLibrary.default_timezone/0, if this can be tested without brittle framework setup.
- [x] #5 StaticAssets hook coverage is added only if it can assert the assigned value through an existing LiveView request without coupling to Phoenix internals.
- [x] #6 No tests are added for Application child ordering, exhaustive route enumeration, or framework-generated static_changed?/1 behavior unless a concrete project regression is identified.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Create `test/music_library/worker/bulk_cron_workers_test.exs` — parameterized smoke tests for all 5 _All_ workers: create fixture data, run perform_job, assert_enqueued for downstream single-item workers.
2. Create `test/music_library_web/browser_pipeline_test.exs` — CSP header test hitting /health, asserting app-specific directives (img-src, worker-src, connect-src, frame-ancestors, base-uri).
3. Create `test/music_library_web/hooks/get_timezone_test.exs` — test timezone assignment with and without connect params through a LiveView request.
4. Evaluate StaticAssets hook coverage — add only if practical via existing LiveView without coupling to Phoenix internals.
5. Skip: Application child ordering, route enumeration, static_changed? return value assertions.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Created 4 test files (9 new tests):

1. **`test/music_library/worker/bulk_cron_workers_test.exs`** (5 tests) — Smoke tests for all 5 _All_ bulk cron workers. Each test creates fixture data, calls perform_job/2, and asserts_enqueued for the expected downstream single-item workers. Follows the pattern from existing batch tests.

2. **`test/music_library_web/browser_pipeline_test.exs`** (1 test) — Asserts the CSP header on /health includes project-specific directives: img-src (Last.fm CDN, Brave, Cover Art Archive), worker-src, connect-src (jsdelivr CDN), frame-ancestors, base-uri.

3. **`test/music_library_web/hooks/get_timezone_test.exs`** (2 tests) — Tests GetTimezone hook via live/2: fallback to default_timezone/0 when no connect params, and explicit timezone assignment via put_connect_params/2. Uses :sys.get_state(view.pid).socket to read socket assigns (pragmatic approach, not constructing a synthetic Socket struct).

4. **`test/music_library_web/hooks/static_assets_test.exs`** (1 test) — Asserts the hook assigns :static_changed as a boolean. Same :sys.get_state approach.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added 9 selective smoke tests across 4 new test files, targeting low-coverage wiring with real regression signal without brittle assertions.

**What changed:**

- **`test/music_library/worker/bulk_cron_workers_test.exs`** — 5 parameterized tests covering all `*All*` bulk cron workers (RecordRefreshAllMusicBrainzData, RecordGenerateAllEmbeddings, ArtistRefreshAllMusicBrainzData, ArtistRefreshAllDiscogsData, ArtistRefreshAllWikipediaData). Each test creates fixture data, runs `perform_job/2`, and verifies via `assert_enqueued` that the correct downstream single-item worker is enqueued. Tests delegate through existing batch flows without duplicating API refresh behavior already covered by single-item worker tests.

- **`test/music_library_web/browser_pipeline_test.exs`** — 1 test asserting the Content-Security-Policy header on `/health` includes all project-specific directives: img-src (Last.fm CDN, Brave Search, Cover Art Archive, archive.org), worker-src (blob for barcode-detector), connect-src (jsdelivr CDN), frame-ancestors, and base-uri.

- **`test/music_library_web/hooks/get_timezone_test.exs`** — 2 tests for the GetTimezone on_mount hook: verifies fallback to `MusicLibrary.default_timezone/0` when no connect params present, and assignment from `put_connect_params/2` when a specific timezone is provided. Uses `:sys.get_state(view.pid).socket.assigns` as a pragmatic approach to read LiveView socket assigns without constructing synthetic Socket structs.

- **`test/music_library_web/hooks/static_assets_test.exs`** — 1 test asserting the StaticAssets hook assigns `:static_changed` as a boolean through a live/2 request. Same `:sys.get_state` approach.

**Tests run:** All 9 new tests pass, plus 135 existing tests in related worker/controller/batch areas pass (0 regressions).

**Excluded by design:** Application child ordering, exhaustive route enumeration, and framework `static_changed?/1` return value assertions (AC#6).

<!-- SECTION:FINAL_SUMMARY:END -->
