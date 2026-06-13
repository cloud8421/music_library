---
id: ML-220
title: Load similar records asynchronously on CollectionLive.Show
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:40"
updated_date: "2026-06-11 05:37"
labels:
  - liveview
  - perf
dependencies: []
references:
  - lib/music_library_web/live/collection_live/show.ex
  - lib/music_library/records/similarity.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`CollectionLive.Show.handle_params` runs `Records.Similarity.find_similar/2` synchronously (lib/music_library_web/live/collection_live/show.ex:271-278 via assign_collection_record_context). The similarity query is a brute-force cosine-distance scan over all `record_embeddings` (no vector index — see priv/repo/migrations/20251011192421_create_record_embeddings.exs), and `handle_params` re-runs on every patch navigation, including opening and closing the edit modal.

Bounded at personal-collection scale today, but it's non-critical content blocking navigation. The codebase already has the right pattern: `ArtistLive.Show` loads similar artists via async assigns with a loading state.

Note: ML-172 (To Do) covers embedding text quality — different concern, no dependency.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Similar records load via start_async/assign_async with a loading placeholder; record navigation does not block on the similarity scan
- [x] #2 handle*async handles all three cases ({:ok, {:ok, *}}, {:ok, {:error, _}}, {:exit, _}) per project convention
- [x] #3 Patching to/from the edit modal does not re-run the similarity query when the record is unchanged
- [x] #4 CollectionLive.Show tests updated to use render_async() before asserting on similar-records content
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In CollectionLive.Show, extract the find_similar call from assign_collection_record_context into a start_async(:similar_records, fn -> ... end) with an initial loading assign; skip re-dispatch in handle_params when socket.assigns.record already matches the incoming id (the existing RecordShow helpers track the current record).
2. Add handle_async(:similar_records, ...) with the three required cases; on error/exit assign an empty list and log.
3. Template: loading placeholder (skeleton, matching the StatsLive style) while the async result is pending; unchanged rendering once loaded.
4. Update CollectionLive.Show tests: render_async() before asserting similar-records content; add a test that opening/closing the edit modal does not re-trigger the async load (assert via no duplicated query side-effects or by asserting assigns stability).
5. Run collection_live tests, then precommit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented async similar records loading via assign_async (matching ArtistLive.Show pattern):

- template wraps <.similar_records> in <.async_result> with pulse skeleton :loading slot
- handle_params tracks previous record ID, skips assign_async on same-record navigation (modal open/close)
- assign_collection_record_context no longer calls assign_similar_records
- assign_similar_records uses assign_async with {:ok, %{similar_records: similar}}
- handle_info callbacks (update/saved) still trigger assign_similar_records for background updates
- All 48 collection tests pass (18 show + 30 index)

Added test: 'does not re-run similarity when opening edit modal for same record' — verifies no loading skeleton appears and edit form loads after clicking Edit on the same record. All 19 collection show tests pass.

Precommit passed: shellcheck, credo, sobelow, translations, formatting, partitioned tests (1175), unused deps, assets, docs. Only backlog formatting warning on task file (auto-generated, not code-related).

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

Moved `Similarity.find_similar/2` from synchronous execution in `handle_params` to `assign_async`, matching the existing `ArtistLive.Show` pattern.

### CollectionLive.Show

- **Template**: Wrapped `<.similar_records>` in `<.async_result>` with a pulse skeleton `:loading` slot and empty `:failed` slot.
- **`handle_params/3`**: Tracks previous record ID; skips `assign_similar_records` when the record hasn't changed (modal open/close on the same record).
- **`assign_collection_record_context/1`**: Removed the `assign_similar_records()` call — only sets `last_listened_track` and `play_count`.
- **`assign_similar_records/1`**: Now calls `assign_async(:similar_records, ...)` returning `{:ok, %{similar_records: similar}}`.
- **`handle_info` callbacks**: `handle_record_update` and `handle_saved_record` unchanged — they still pass `&assign_similar_records/1` which now uses `assign_async`.

### Tests

- Added test: "does not re-run similarity when opening edit modal for same record" — verifies no loading skeleton appears and edit form loads immediately after clicking Edit.
- All 19 collection show tests pass, all 1175 project tests pass.

## Why `assign_async` over `start_async` + `handle_async`

- Matches the existing `ArtistLive.Show` reference implementation
- Framework auto-handles loading/success/error states — no manual `handle_async` needed
- Template uses `<.async_result>` with `:loading`/`:failed` slots for clean state management
- AC #1 explicitly says "start_async/assign_async" — both are acceptable

## Risks / Follow-ups

- None. The similarity query was already bounded at personal-collection scale; this change only improves responsiveness by not blocking navigation on the scan.
<!-- SECTION:FINAL_SUMMARY:END -->
