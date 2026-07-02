---
id: ML-188
title: Fix form edit + background update race in Show LiveViews
status: Done
assignee: []
created_date: "2026-05-19 08:42"
updated_date: "2026-05-19 10:18"
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
  - lib/music_library_web/live_helpers/record_actions.ex
  - test/music_library_web/live/collection_live/show_test.exs
  - test/music_library_web/live/wishlist_live/show_test.exs
  - docs/architecture.md
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

**Why the guard works (Ecto changeset behavior):** When `live_action == :edit` and we keep `@record = v1` on the socket, RecordForm's form params still carry v1's field values. On save, `Records.update_record(v1, params)` builds a changeset from `v1`. Fields that the worker modified (e.g., genres) will NOT appear in `params` because the form was rendered before the worker's update — and Ecto's `cast/3` only includes fields in `changes` when they differ from the original struct. So the worker's changes survive the save because they aren't in the changeset. Fields the user explicitly edited will still be updated correctly.

**Known limitation (edge case):** If the user manually edits the exact same field the worker modified (e.g., user adds "jazz" to genres while worker adds "rock"), the user's save will overwrite the worker's change. This is inherent to any unversioned form-edit model and is proportionate to the low-probability, medium-severity nature of this bug in a single-user app.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 handle_info({:update, record}) skips assign(:record, ...) when live_action == :edit in CollectionLive.Show
- [x] #2 handle_info({:update, record}) skips assign(:record, ...) when live_action == :edit in WishlistLive.Show
- [x] #3 Warning toast shown to user when background update occurs during edit (different wording from normal info toast)
- [x] #4 handle_info({:update, record}) still works normally when live_action == :show
- [x] #5 When user navigates away from edit, handle_params re-fetches fresh record with worker changes
- [x] #6 Mismatched record.id still handled as no-op (socket unchanged)
- [x] #7 Tests added for all three cases: :edit guard, :show normal path, mismatched-id no-op
- [x] #8 docs/architecture.md updated to mention live_action guard
- [x] #9 Comment added in RecordActions.handle_record_updated/2 noting intentional bypass during :edit

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation plan

### 1. Guard `handle_info({:update, record})` in CollectionLive.Show (line ~474)

Add `live_action` check inside the existing `handle_info({:update, record}, socket)`:

- When `live_action == :show`: existing behavior — call `RecordActions.handle_record_updated(record)` + `assign_similar_records()`
- When `live_action == :edit`: show warning toast, skip all assigns
- When `record.id != socket.assigns.record.id`: no-op (unchanged)

The toast wording should differ from the existing "Record updated in the background" toast (from `RecordActions.handle_record_updated`) to signal that the user's edits may be stale:

```elixir
put_toast(socket, :warning, gettext("Record was updated in the background. Your edits may be stale — save and re-open to see the latest data."))
```

**Note:** `put_toast` and `gettext` are already available in both LiveViews via `use MusicLibraryWeb, :live_view` — no new imports needed.

### 2. Same guard in WishlistLive.Show (line ~367)

Identical pattern, but WishlistLive.Show's handler does NOT call `assign_similar_records()` — only `RecordActions.handle_record_updated(socket, record)`. Apply the same `live_action` guard.

### 3. Comment in RecordActions.handle_record_updated/2

Add a comment noting that `handle_record_updated/2` is intentionally bypassed during `:edit` live_action by the callers. This prevents future refactors from assuming it's always called in `handle_info({:update, record})`.

### 4. Tests

Add tests in:

- `test/music_library_web/live/collection_live/show_test.exs`
- `test/music_library_web/live/wishlist_live/show_test.exs`

Test cases:

- `handle_info({:update, record})` with `live_action == :edit` → `@record` unchanged, warning toast present
- `handle_info({:update, record})` with `live_action == :show` → `@record` updated, info toast present ("Record updated in the background")
- `handle_info({:update, other_record})` with mismatched ID → no-op (socket unchanged)

Run: `mix test test/music_library_web/live/collection_live/show_test.exs test/music_library_web/live/wishlist_live/show_test.exs`

### 5. Manual verification

- Open a record show page → from IEx: `Records.notify_update(record)` → confirm "Record updated in the background" toast + UI refreshes
- Open edit modal → from IEx: `Records.notify_update(record)` → confirm warning toast, record on page stays as-is
- Click Save in the modal → confirm no data loss (worker's changes survive)
- Navigate away from edit → confirm `handle_params` loads fresh record with worker changes
- Test with a mismatched-ID record: send `{:update, different_record}` → confirm socket unchanged

### 6. Documentation

- Update `docs/architecture.md`: the existing line about `handle_info/2` validating inbound record updates against `socket.assigns.record.id` should also mention the `live_action` guard for form-edit safety
- Update the task's final summary with a brief note about the design decision

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added `live_action` guard to `handle_info({:update, record})` in both CollectionLive.Show and WishlistLive.Show. When the user is editing a record (`live_action == :edit`), background worker updates are skipped and a distinct warning toast ("Your edits may be stale — save and re-open...") is shown instead of silently overwriting the socket. When showing (`live_action == :show`), existing behavior is unchanged — the record updates and shows "Record updated in the background". Mismatched-ID records remain a no-op.

This prevents the race where a background worker (PopulateGenres, RefreshCover, etc.) updates the DB and broadcasts `{:update, v2}` while the user's edit modal is open with v1. The guard keeps `@record = v1` on the socket so the form saves only user-changed fields via Ecto changeset semantics. When the user navigates away from edit, `handle_params` re-fetches the fresh record with worker changes.

6 tests added (3 per LiveView), covering: `:show` normal path, `:edit` guard path, and mismatched-ID no-op. Architecture docs updated with guard description.

<!-- SECTION:FINAL_SUMMARY:END -->
