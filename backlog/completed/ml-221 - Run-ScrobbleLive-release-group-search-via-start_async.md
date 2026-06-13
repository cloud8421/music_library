---
id: ML-221
title: Run ScrobbleLive release-group search via start_async
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 13:06"
labels:
  - liveview
  - fix
dependencies: []
references:
  - lib/music_library_web/live/scrobble_live/index.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`ScrobbleLive.Index` performs the MusicBrainz release-group search inside `handle_info` (lib/music_library_web/live/scrobble_live/index.ex:145-160), dispatched via `send(self(), {:perform_search, query})`. The send/handle_info indirection lets the loading state render first, but the HTTP call still runs in the LiveView process: MusicBrainz requests sit behind a 1000 ms rate-limit cooldown plus network latency, and every subsequent event on the page queues behind the call.

`start_async`/`handle_async` is the established pattern in this codebase for exactly this (e.g. ArtistLive.Show, StatsLive.Index).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The MusicBrainz search runs via start_async; the send(self(), ...)/handle_info pair is removed
- [x] #2 handle*async covers all three cases ({:ok, {:ok, *}}, {:ok, {:error, _}}, {:exit, _}); the error path keeps the existing user-facing failure message
- [x] #3 Loading state behaviour is preserved (spinner while searching, cleared on result/error)
- [x] #4 A rapid second search while one is in flight does not produce stale results overwriting newer ones (cancel or ignore superseded results)
- [x] #5 ScrobbleLive tests updated (Req.Test stub) covering success and failure paths
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Keep the explicit `loading` assign for ML-221; the broader AsyncResult/loading-slot refactor is tracked separately as ML-226.
2. Route both query-param searches and search form events through a shared `run_search/2` helper in `ScrobbleLive.Index`.
3. For non-blank queries, assign `search_query` and `loading: true`, then call `start_async({:search, query}, fn -> MusicBrainz.search_release_group(query, limit: 20) end)`.
4. Implement `handle_async({:search, query}, ...)` for success, API error, and task-exit cases. Apply results or errors only when the async query matches `socket.assigns.search_query`; ignore stale results.
5. For blank queries, clear results and loading state without starting a search.
6. Update ScrobbleLive tests with shared Req.Test stubs and `render_async`, covering success, empty results, API failure, task exit, loading state, and stale-result protection.
7. Run the focused ScrobbleLive test file and `mise run dev:precommit`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Pre-flight complete: read docs/architecture.md and docs/project-conventions.md; reviewed Backlog execution/finalization workflow; loaded task plan/acceptance criteria; loaded relevant ui-framework, testing, and external-api-integration skills. Awaiting user confirmation before code changes.

User approved the ML-221 plan with explicit loading state. Created follow-up task ML-226 for the broader AsyncResult/loading-slot refactor, dependent on ML-221.

Implemented ScrobbleLive release-group search with `start_async` using query-tagged async names. `handle_async` now covers success, API error, and task-exit cases; stale results are ignored by comparing the async query with the current search query. Updated ScrobbleLive tests with shared Req.Test stubs, async waits, success/no-result/failure/exit/loading/stale-result coverage. Focused test run passed: `mix test test/music_library_web/live/scrobble_live/index_test.exs` (11 passed).

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Summary:

- Moved ScrobbleLive release-group search from the `send(self(), ...)` / `handle_info` path to `start_async` / `handle_async`.
- Kept the explicit loading assign for this task and added query-tagged async names so stale results are ignored when a newer search is active.
- Updated ScrobbleLive tests to use shared Req.Test stubs and async waits for success, empty results, loading, stale-result, API error, and task-exit coverage.

Tests:

- `mix test test/music_library_web/live/scrobble_live/index_test.exs`
- `mise run dev:precommit`

Risks / follow-ups:

- Follow-up task ML-226 tracks the broader AsyncResult/loading-slot refactor requested by the user.
<!-- SECTION:FINAL_SUMMARY:END -->
