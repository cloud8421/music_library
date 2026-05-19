---
id: ML-188
title: Fix form edit + background update race in Show LiveViews
status: To Do
assignee: []
created_date: "2026-05-19 08:42"
labels:
  - audit
  - bug
  - race-condition
  - liveview
  - pubsub
dependencies: []
documentation:
  - >-
    audits/phase3-concurrent-state-safety/doc-26 -
    Audit-Report-Concurrent-State-Change-Safety-Phase-3.md
modified_files:
  - lib/music_library_web/live/collection_live/show.ex
  - lib/music_library_web/live/wishlist_live/show.ex
priority: medium
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When a user is editing a record in a modal (`live_action == :edit`) and a background worker (e.g., PopulateGenres, RefreshCover) broadcasts `{:update, record}`, the Show LiveView's `handle_info` overwrites `@record` on the socket. The next save by the user can silently revert the worker's changes because the form data was based on the stale `@record`.

**Race flow:**

1. User opens edit modal with record v1
2. Background worker updates DB to v2, broadcasts `{:update, v2}`
3. `handle_info` assigns v2 → RecordForm gets v2 via `update/2`
4. User saves → stale form params overwrite worker's v2 changes in DB

**Fix:** Add a `live_action` guard to `handle_info({:update, record})` in both CollectionLive.Show and WishlistLive.Show. When `live_action == :edit`, skip assigning the updated record and show a warning toast that the record was updated in the background. The fresh record will be loaded on the next `handle_params` when the user navigates away from edit mode.

**Source:** Audit doc-26 (Phase 3), Recommendation #1.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 handle_info({:update, record}) skips assign(:record, ...) when live_action == :edit in CollectionLive.Show
- [ ] #2 handle_info({:update, record}) skips assign(:record, ...) when live_action == :edit in WishlistLive.Show
- [ ] #3 Warning toast shown to user when background update occurs during edit
- [ ] #4 handle_info({:update, record}) still works normally when live_action == :show
- [ ] #5 When user navigates away from edit, handle_params re-fetches fresh record with worker changes
<!-- AC:END -->
