---
id: ML-220
title: Load similar records asynchronously on CollectionLive.Show
status: To Do
assignee: []
created_date: "2026-06-10 10:40"
updated_date: "2026-06-10 10:57"
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

- [ ] #1 Similar records load via start_async/assign_async with a loading placeholder; record navigation does not block on the similarity scan
- [ ] #2 handle*async handles all three cases ({:ok, {:ok, *}}, {:ok, {:error, _}}, {:exit, _}) per project convention
- [ ] #3 Patching to/from the edit modal does not re-run the similarity query when the record is unchanged
- [ ] #4 CollectionLive.Show tests updated to use render_async() before asserting on similar-records content
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In CollectionLive.Show, extract the find_similar call from assign_collection_record_context into a start_async(:similar_records, fn -> ... end) with an initial loading assign; skip re-dispatch in handle_params when socket.assigns.record already matches the incoming id (the existing RecordShow helpers track the current record).
2. Add handle_async(:similar_records, ...) with the three required cases; on error/exit assign an empty list and log.
3. Template: loading placeholder (skeleton, matching the StatsLive style) while the async result is pending; unchanged rendering once loaded.
4. Update CollectionLive.Show tests: render_async() before asserting similar-records content; add a test that opening/closing the edit modal does not re-trigger the async load (assert via no duplicated query side-effects or by asserting assigns stability).
5. Run collection_live tests, then precommit.
<!-- SECTION:PLAN:END -->
