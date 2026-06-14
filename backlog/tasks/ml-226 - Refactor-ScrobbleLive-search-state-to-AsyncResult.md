---
id: ML-226
title: Refactor ScrobbleLive search state to AsyncResult
status: Done
assignee:
  - pi
created_date: "2026-06-10 12:57"
updated_date: "2026-06-14 12:04"
labels:
  - liveview
  - refactor
  - follow-up
dependencies:
  - ML-221
references:
  - lib/music_library_web/live/scrobble_live/index.ex
  - test/music_library_web/live/scrobble_live/index_test.exs
  - >-
    backlog/tasks/ml-221 -
    Run-ScrobbleLive-release-group-search-via-start_async.md
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
priority: low
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Follow-up to ML-221. ML-221 keeps the existing explicit `loading` assign while moving the MusicBrainz release-group search out of the LiveView process. This task evaluates and applies the broader cleanup: represent the ScrobbleLive release-group search state with LiveView async-result rendering so loading/success/failure UI is driven by the async state instead of a standalone loading flag.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 ScrobbleLive release-group search state is represented with LiveView async-result state instead of a standalone loading flag.
- [x] #2 The visible search behaviour remains unchanged: spinner while searching, results on success, current user-facing failure message on error, and no results message only when appropriate.
- [x] #3 Superseded in-flight searches still cannot overwrite newer search results.
- [x] #4 ScrobbleLive tests cover success and failure paths with Req.Test stubs and wait for async completion where needed.
- [x] #5 Relevant ScrobbleLive tests pass.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Review the final ML-221 implementation and the ScrobbleLive search template to identify every place that reads or mutates the explicit loading state.
2. Replace the standalone loading flag with LiveView async-result state initialized in the LiveView assigns, choosing the smallest API surface that preserves the existing search/results assigns.
3. Update the template to render loading, success, empty, and failure states through the async-result rendering path while preserving the current visible copy and layout.
4. Keep the ML-221 stale-result protection intact so older in-flight searches cannot overwrite newer results.
5. Update ScrobbleLive tests to cover success and failure with Req.Test stubs and async waits, then run the relevant ScrobbleLive test file.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Replaced the standalone `loading` boolean assign in `ScrobbleLive.Index` with a LiveView `AsyncResult`-driven `search` assign following the patterns used in `ReleaseGroupShow` and `StatsLive.Index`.

Changes to `lib/music_library_web/live/scrobble_live/index.ex`:

- Added `alias Phoenix.LiveView.AsyncResult`
- `mount/3`: replaced `loading: false` / `search_results: []` with `search: AsyncResult.loading()`
- `run_search/2`: removed `loading` assign; starts async with `start_async({:search, query}, ...)`; resets to `AsyncResult.loading()` on empty query
- `handle_async/3`: uses `AsyncResult.ok/2` on success and `AsyncResult.failed/2` on error/exit instead of mutating `loading` and `search_results`
- `search_failed/1`: uses `AsyncResult.failed/2` instead of `assign(loading: false)`
- Template: replaced three conditional blocks (results/loading/no-results) with `<.async_result :let={result} assign={@search}>` with `<:loading>`, `<:failed>`, and default slots. Results and no-results message render in the default slot based on `result.release_groups`
- Stale-result protection maintained: query-tagged async names + `current_search?/2` guard

Tests: 11/11 ScrobbleLive index tests pass. Full pre-commit suite (1177 tests, Credo, Sobelow, format) clean.

<!-- SECTION:FINAL_SUMMARY:END -->
