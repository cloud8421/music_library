---
id: doc-13
title: "Research: Updating index views when background import finishes"
type: specification
created_date: "2026-05-08 05:44"
updated_date: "2026-05-08 05:53"
---

# Research: Updating index views when background import finishes

## Current State

### Import Workers

- `ImportFromMusicbrainzRelease` (queue: `music_brainz`, max_attempts: 3) — used by barcode scan batch imports. Calls `Records.import_from_musicbrainz_release/2` which delegates to `Records.Import.import_from_musicbrainz_release_group/2` → `Records.create_record/1`.
- `ImportFromMusicbrainzReleaseGroup` (queue: `music_brainz`, max_attempts: 3, unique: 300s) — used by cart-style multi-record import. Calls `Records.import_from_musicbrainz_release_group/2` → `Records.create_record/1`.

**Neither worker broadcasts any PubSub event after successful import.**

### Records Context

- `Records.create_record/1` — creates a record, extracts colors, triggers artist info refresh. Does NOT call `notify_update/1`.
- `Records.update_record/2` — updates a record, triggers artist info refresh. Does NOT call `notify_update/1`.
- `Records.notify_update/1` — broadcasts `{:update, record}` on topic `"records:#{record.id}"`. Currently called only by enrichment workers (RefreshCover, PopulateGenres, RecordRefreshMusicBrainzData, GenerateRecordEmbedding).

### Show Pages (per-record)

- `CollectionLive.Show` and `WishlistLive.Show` subscribe to `"records:#{record.id}"` in `handle_params`, unsubscribe on navigation, and handle `{:update, record}` by updating their assigns.
- This mechanism works for individual record updates but is not applicable to index pages (which display many records).

### Index Pages (Collection / Wishlist)

- `CollectionLive.Index` and `WishlistLive.Index` use `LiveHelpers.IndexActions` for shared logic: `apply_index_action/2` loads records via `load_and_assign_records/2` which calls `context_module.search_records(...)` and `stream(:records, records, reset: true)`.
- **Neither index page subscribes to any PubSub topic.**
- They receive component messages: `{:imported_single, record}` (navigates to show), `{:imported_async, count}` (shows toast, patches to index), `{:saved, _record}` (reloads records).
- When `handle_cart_imported_async` fires, it only shows a toast — it does NOT reload the stream. The user sees stale data until they manually trigger a reload (search, sort, navigate away and back).

### Async Import Flow (AddRecord Component)

- Single item: synchronous via `start_async` → `handle_async` sends `{:imported_single, record}` → parent navigates to show page.
- Multiple items (2+): enqueues Oban jobs via `Oban.insert_all` → sends `{:imported_async, count}` → parent shows toast and patches to index. The index reloads from scratch via `apply_index_action` on the patch, but this happens immediately (before the Oban jobs complete). New records appear only after the jobs finish and the user manually refreshes.

### Async Import Flow (BarcodeScanner Component)

- When `import_releases` fires with 2+ new records: sync records import immediately, async records enqueue `ImportFromMusicbrainzRelease` jobs → shows toast → patches to `/collection?#{qs}`. Same issue: the index reloads before the jobs complete.

## Problem Summary

When background import jobs complete, the collection/wishlist index pages don't automatically pick up the new records. Users must manually refresh. The `handle_cart_imported_async` path reloads records, but does so at enqueue time (before jobs complete), not at job completion time.

## Viable Implementation Routes

### Route A: Broadcast from import workers on a new index topic

**What**: Add a new PubSub topic `"records:index_changed"`. Import workers broadcast on it after `{:ok, record}`. Index pages subscribe and reload.

**Changes**:

1. Add `Records.broadcast_index_changed/0` — broadcasts `:records_index_changed` on `"records:index_changed"`.
2. In `ImportFromMusicbrainzRelease.perform/1`, after `{:ok, _record}` → `:ok`, call `Records.broadcast_index_changed()` before returning.
3. Same for `ImportFromMusicbrainzReleaseGroup`.
4. In `CollectionLive.Index.mount/3`, subscribe to `"records:index_changed"`.
5. In `WishlistLive.Index.mount/3`, subscribe to `"records:index_changed"`.
6. Add `handle_info(:records_index_changed, socket)` in both index views → calls `load_and_assign_records`.

**Pros**:

- Minimal blast radius — only affects import workers and index views.
- Very simple (2 workers, 2 LiveViews, 1 new context function).
- Follows existing PubSub patterns in the project.
- Can be extended later to cover other CRUD paths.

**Cons**:

- Only covers background import paths. Other record creation paths (if any are added later) would need separate treatment.
- Index views reload ALL records on every change, even if the user is deep in pagination. But since the `stream(:records, records, reset: true)` is already called on searches/sorts, this matches existing behavior.

### Route B: Broadcast from `Records.create_record/1` and `Records.update_record/1`

**What**: Call `broadcast_index_changed/0` inside the centralized CRUD functions, so ANY record creation or update triggers index refresh.

**Changes**:

1. Add `Records.broadcast_index_changed/0`.
2. Call it in `Records.create_record/1` after successful insert.
3. Call it in `Records.update_record/2` after successful update.
4. Call it in `Records.delete_record/1` after successful delete.
5. Subscribe in index views (same as Route A).

**Pros**:

- Comprehensive — any record mutation anywhere triggers index refresh.
- Covers future changes without extra work.
- Symmetric: create/update/delete all broadcast.

**Cons**:

- Larger blast radius. Every record edit on a show page would trigger index reloads in other browser tabs.
- Potential for "noisy" reloads if users have many tabs open.
- Requires careful review of all call sites for `create_record`, `update_record`, `delete_record` to ensure no unexpected side effects.
- The `RecordForm` component already sends `{:saved, _record}` to the index parent, which calls `handle_record_saved` → `load_and_assign_records`. Adding PubSub on top of that would cause double reloads in the same process (though harmless, just wasteful).

### Route C: Extend `notify_update` to also broadcast on an index topic

**What**: Modify the existing `notify_update/1` to broadcast on both the per-record topic (existing) and a new index topic.

**Changes**:

1. Modify `Records.notify_update/1` to also broadcast `:records_index_changed` on `"records:index_changed"`.
2. Subscribe in index views (same as Route A).

**Pros**:

- Leverages existing code — no new call sites needed in workers.
- All enrichment workers (RefreshCover, PopulateGenres, etc.) automatically trigger index refresh. E.g., if a cover refresh changes an image and you're on the index, you'd see the new cover.

**Cons**:

- `notify_update` is currently only for per-record show page updates. Changing its semantics to also trigger index reloads is a behavior change for all existing callers.
- Very noisy — every cover refresh, genre population, embedding generation would trigger full index reloads. This may be undesirable.
- Muddies the separation between per-record update notification and index-level change notification.

### Route D: Use a Phoenix.PubSub topic with per-section filtering (collection vs wishlist)

**What**: Two separate topics: `"index:collection"` and `"index:wishlist"`. Import workers broadcast only on the relevant topic based on whether the imported record is purchased (collection) or not (wishlist).

**Changes**:

1. Add `Records.broadcast_index_changed(:collection)` and `Records.broadcast_index_changed(:wishlist)`.
2. Import workers determine the destination based on `purchased_at` value.
3. CollectionLive.Index subscribes to `"index:collection"`, WishlistLive.Index to `"index:wishlist"`.

**Pros**:

- Finer granularity — importing a wishlist record doesn't trigger collection reload.
- More efficient.

**Cons**:

- More complex — two topics, logic to determine which to broadcast on.
- A record moving from wishlist to collection (via `add-to-collection` event in WishlistLive.Index) would need to broadcast on BOTH topics. This adds complexity.
- Over-engineering for the current problem scope.

## Recommendation: Route A

Route A is the simplest approach that directly solves the stated problem. It follows existing project patterns (PubSub topics, `handle_info` in LiveViews, `Records.notify_update` precedent). It has the smallest blast radius and can be extended later if needed.

The decision to NOT use Route B or C is deliberate:

- Route B's comprehensive approach can be adopted later if the need arises.
- Route C changes the semantics of an existing function used by 4 other workers.
- Route D adds complexity that isn't justified by the current problem.

## Architecture Impact (Route A)

- **New PubSub topic**: `"records:index_changed"` on `MusicLibrary.PubSub`
- **Schemas affected**: None (no DB changes)
- **Contexts affected**: `Records` (new `broadcast_index_changed/0` function)
- **Workers affected**: `ImportFromMusicbrainzRelease`, `ImportFromMusicbrainzReleaseGroup`
- **Routes/LiveViews affected**: `CollectionLive.Index`, `WishlistLive.Index`
- **Supervision tree**: No changes
- **External APIs**: No changes
- **UI components**: No changes
