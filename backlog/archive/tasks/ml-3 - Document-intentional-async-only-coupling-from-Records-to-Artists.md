---
id: ML-3
title: Document intentional async-only coupling from Records to Artists
status: To Do
assignee: []
created_date: "2026-04-20 08:44"
updated_date: "2026-04-20 08:44"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/181"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-19 · closed 2026-04-19 · not planned_

## Summary

`Records.create_record/1` calls `Artists.refresh_artist_info_async/1` and `Records.delete_record/1` calls `Artists.prune_artist_info_async/1`. Both are deliberately `*_async` (Oban enqueues) to avoid a runtime cycle with the embedding/genre regeneration path in `Artists`. The intent is not captured inline.

## Evidence

- `lib/music_library/records.ex:385` — `Artists.refresh_artist_info_async/1` call
- `lib/music_library/records.ex:415` — `Artists.prune_artist_info_async/1` call

No comment explaining why the async form is required. A future refactor that decides to "just inline the synchronous version" would reintroduce runtime coupling.

## Fix

Add a short inline comment above each call site explaining:

```elixir
# async to avoid a runtime cycle:
# Records.create/delete -> Artists.refresh/prune (sync) -> Records (embedding regeneration)
Artists.refresh_artist_info_async(artist)
```

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Inline comments added at records.ex:385 and :415
- [ ] #2 Comments explain the runtime-cycle motivation, not just "it's async"

<!-- AC:END -->
