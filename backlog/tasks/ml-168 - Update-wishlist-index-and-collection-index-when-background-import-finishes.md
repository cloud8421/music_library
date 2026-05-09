---
id: ML-168
title: Update wishlist index and collection index when background import finishes
status: To Do
assignee: []
created_date: "2026-05-08 05:40"
updated_date: "2026-05-09 06:04"
labels:
  - ready
dependencies: []
documentation:
  - >-
    backlog/docs/doc-13 -
    Research-Updating-index-views-when-background-import-finishes.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When importing multiple records, the application performs the import in the background. The collection and wishlist index views should automatically pick up the new records via pubsub event fired when a record is successfully imported.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Importing 2+ records via the AddRecord cart automatically updates the collection index without manual refresh
- [ ] #2 Importing 2+ records via the AddRecord cart automatically updates the wishlist index without manual refresh
- [ ] #3 Importing 2+ records via barcode scan automatically updates the collection index without manual refresh
- [ ] #4 Existing import worker tests pass
- [ ] #5 New tests verify PubSub broadcast from import workers after success
- [ ] #6 No regressions in CollectionLive.Index or WishlistLive.Index behavior
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Implementation Plan — Route A (Revised)

## Objective Alignment

When background import Oban jobs complete, the collection and wishlist index pages must automatically show new records without requiring a manual refresh. This is achieved by broadcasting a PubSub event from the import workers after successful import, and having the index LiveViews subscribe to that event and reload their record streams.

## Implementation Steps

### Step 1: Add `broadcast_index_changed/0` to the Records context

**File**: `lib/music_library/records.ex`

Add a new public function in the PubSub section (alongside `subscribe/1`, `unsubscribe/1`, `notify_update/1`):

```elixir
@doc """
Broadcasts that the records index has changed (new record imported, deleted, etc.).
Index LiveViews subscribe to this topic to auto-refresh.
"""
@spec broadcast_index_changed() :: :ok
def broadcast_index_changed do
  Phoenix.PubSub.broadcast(MusicLibrary.PubSub, "records:index_changed", :records_index_changed)
end
```

**Verification**: Run `mix test test/music_library/records_test.exs` to confirm existing tests still pass. The function is a simple PubSub wrapper — no new schema or DB logic.

---

### Step 2: Add `subscribe_to_index/0` to the Records context

**File**: `lib/music_library/records.ex`

Add a convenience function for subscribing, in the same PubSub section:

```elixir
@doc """
Subscribes the calling process to records index change notifications.
"""
@spec subscribe_to_index() :: :ok | {:error, term()}
def subscribe_to_index do
  Phoenix.PubSub.subscribe(MusicLibrary.PubSub, "records:index_changed")
end
```

**Verification**: Compile-check. Used by Steps 4 and 5.

---

### Step 3: Add `handle_index_changed/1` to IndexActions

**File**: `lib/music_library_web/live_helpers/index_actions.ex`

Add a public helper that index views can call from `handle_info`:

```elixir
@doc """
Handles a PubSub notification that records have changed.
Reloads the record stream using the current parameters.
"""
def handle_index_changed(socket) do
  load_and_assign_records(socket, socket.assigns.record_list_params)
end
```

Note: `load_and_assign_records/2` is already a public function (`def`, not `defp`) in this module, so the wrapper delegates directly to it.

**Verification**: Used by Steps 4 and 5. The function delegates to the existing `load_and_assign_records/2` which is already well-tested implicitly.

---

### Step 4: Subscribe to `"records:index_changed"` in CollectionLive.Index

**File**: `lib/music_library_web/live/collection_live/index.ex`

In `mount/3`, add a subscription (only when connected — skip during dead render):

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Records.subscribe_to_index()
  end

  {:ok,
   socket
   |> assign(:current_section, :collection)
   # ... rest of existing assigns ...
  }
end
```

Add a `handle_info` clause. **Guard on `live_action`** to avoid unnecessary reloads when the user is on sub-routes where the index grid is hidden behind a modal (e.g., `:import`, `:barcode_scan`):

```elixir
@impl true
def handle_info(:records_index_changed, socket) when socket.assigns.live_action in [:index, :edit] do
  {:noreply, IndexActions.handle_index_changed(socket)}
end

def handle_info(:records_index_changed, socket) do
  {:noreply, socket}
end
```

Rationale for the guard: when the user is on `/collection/import` or `/collection/scan`, the index grid is behind a full-screen modal. Reloading it would waste a query and briefly reassign `page_title`, causing a visual flicker in the modal title. The `:index` and `:edit` actions are the only ones where the grid is visible and should be refreshed. When the user returns to `:index` from a sub-route, `handle_params` already reloads — so no records are missed.

**Verification**:

- Run `mix test test/music_library_web/live/collection_live/` (if tests exist; create a basic test if not — see Step 7)
- **Manual browser verification (required)**: Import 2+ records via the AddRecord cart, confirm they appear automatically on the collection index without manual refresh. Also verify that the page title in the import modal does not flicker during background import.

---

### Step 5: Subscribe to `"records:index_changed"` in WishlistLive.Index

**File**: `lib/music_library_web/live/wishlist_live/index.ex`

Same pattern as Step 4. Add subscription in `mount/3` (only when connected) and a guarded `handle_info` clause. The WishlistLive.Index handles `:index`, `:edit`, and `:import` actions — guard on `:index` and `:edit` only.

**Verification**: Same as Step 4, but for the wishlist index page. Manual browser verification required.

---

### Step 6: Call `broadcast_index_changed/0` from import workers after success

**Files**:

- `lib/music_library/worker/import_from_musicbrainz_release.ex`
- `lib/music_library/worker/import_from_musicbrainz_release_group.ex`

In each `perform/1`, after the `{:ok, _record}` match before returning `:ok`, insert a call to `Records.broadcast_index_changed()`.

Example for `ImportFromMusicbrainzRelease`:

```elixir
def perform(%Oban.Job{args: %{"release_id" => release_id} = args}) do
  # ... existing opts setup ...
  case MusicLibrary.Records.import_from_musicbrainz_release(release_id, opts) do
    {:ok, _record} ->
      Records.broadcast_index_changed()
      :ok
    other ->
      ErrorHandler.to_oban_result(other)
  end
end
```

Same pattern for `ImportFromMusicbrainzReleaseGroup`.

**Verification**:

- Run `mix test test/music_library/worker/import_from_musicbrainz_release_test.exs`
- Run `mix test test/music_library/worker/import_from_musicbrainz_release_group_test.exs`
- Existing tests should continue to pass. New assertions added in Step 7.

---

### Step 7: Write tests

**Tests to add**:

1. **`test/music_library/records_test.exs`**: Add a test for `broadcast_index_changed/0` and `subscribe_to_index/0`. Subscribe, call `broadcast_index_changed/0`, assert_receive `:records_index_changed`.

2. **`test/music_library/worker/import_from_musicbrainz_release_test.exs`**: Add test "broadcasts index_changed after successful import". Subscribe to `"records:index_changed"` before `perform_job`, assert_receive `:records_index_changed` after a successful import.

3. **`test/music_library/worker/import_from_musicbrainz_release_group_test.exs`**: Same pattern as above.

4. **LiveView integration tests**: If existing index LiveView test files exist, add a test that mounts the LiveView as `:index`, sends the `:records_index_changed` message, and verifies the stream is reloaded. If no index LiveView test files exist, create a basic test file with a record fixture. Additionally, add a test verifying that the message is ignored (no-op) when `live_action` is `:import` (guard clause test).

5. **End-to-end browser verification (required, manual)**: Import 2+ records via each path (cart and barcode scan) and confirm:
   - Collection index auto-updates with new records
   - Wishlist index auto-updates with new records
   - No visual flicker or title glitch in modals during background import

**Verification**: `mix test` passes.

---

## Design Decisions & Tradeoffs

### Why a single topic for both collection and wishlist?

Both import workers handle both collection records (purchased_at set) and wishlist records (purchased_at nil). There is no clean way to determine which index to notify before the import completes. Using a single `"records:index_changed"` topic means both index pages reload when either type of record is imported. This is slightly wasteful (one extra FTS query on the non-matching index) but the cost is negligible. The alternative — inspecting the record after import and broadcasting to a type-specific topic — adds complexity for no practical gain.

### Why guard `handle_info` on `live_action`?

Without the guard, when a background import completes while the user is on `/collection/import` (modal open), `load_and_assign_records` reassigns `page_title` from "Add new Record · Collection" to "Collection", causing a brief visual flicker in the modal title. The guard prevents this by only reloading when the grid is actually visible (`:index` and `:edit` actions). When the user closes the modal and returns to `:index`, `handle_params` triggers a fresh load anyway — no records are missed.

### Double-reload on async import (harmless)

When the user triggers a batch import, `handle_cart_imported_async` already calls `push_patch` to the base index path, which triggers `handle_params` → `apply_index_action` → `load_and_assign_records`. When the worker later completes, the PubSub broadcast triggers a second `load_and_assign_records`. This is a harmless double-load (one extra FTS query) — not worth optimizing.

---

## Architecture Impact

| Touchpoint                     | Impact                                                                                                      |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| **PubSub topic**               | NEW: `"records:index_changed"` on `MusicLibrary.PubSub` with message `:records_index_changed`               |
| **Schemas**                    | None                                                                                                        |
| **Records context**            | + `broadcast_index_changed/0`, + `subscribe_to_index/0` (2 new functions)                                   |
| **Import workers**             | Both modified to call `broadcast_index_changed/0` after success                                             |
| **CollectionLive.Index**       | + subscription in `mount`, + two `handle_info(:records_index_changed, ...)` clauses (guarded and catch-all) |
| **WishlistLive.Index**         | + subscription in `mount`, + two `handle_info(:records_index_changed, ...)` clauses (guarded and catch-all) |
| **IndexActions (LiveHelpers)** | + `handle_index_changed/1` public function                                                                  |
| **Supervision tree**           | No changes                                                                                                  |
| **External APIs**              | No changes                                                                                                  |
| **UI components**              | No changes                                                                                                  |
| **Routes**                     | No changes                                                                                                  |

## Performance Profile

- **PubSub broadcast**: O(1) — broadcasts to all subscribers of the topic. In production, this is 0–2 subscribers (the two index LiveViews, if the user has those pages open). Dead subscribers are automatically cleaned up by Phoenix.PubSub's process monitoring.
- **Record reload in index**: The index reload calls `context_module.search_records(query, limit: 72, offset: current_offset, order: current_order)`. This is a single FTS5 query + records table join, equivalent to what happens on any search/sort. At most one query per index page open.
- **No N+1 risk**: The `search_records` function already preloads associations (artists, etc.) via the FTS5 join pattern.
- **Memory**: No additional memory footprint. The PubSub message is a single atom `:records_index_changed`.
- **Throttling**: Not needed. Import workers are rate-limited by the `:music_brainz` queue (concurrency: 1), so broadcasts are naturally spaced. Even during batch imports, the broadcast happens once per job completion, not once per record search.
- **Guard clause avoids wasteful work**: When the user is on a sub-route (`:import`, `:barcode_scan`), the reload is skipped entirely, saving one FTS query.

## Benchmarking Requirements

No benchmarks needed. The change adds no new database queries beyond what already runs on every search/sort action. The PubSub broadcast is an O(1) in-process message delivery to at most 2 subscribers.

## Cost Profile

No paid resources consumed. The change is purely in-process PubSub and existing database queries. No additional API calls, compute, or storage costs.

## Production Changes

**None required.** No environment variables, service provisioning, database migrations, DNS changes, or firewall rules needed. This is a pure application code change deployed via the normal CI/CD pipeline.

## Documentation Updates

| Document                               | Changes Needed                                                                                                                                                                        |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/architecture.md`                 | Add `"records:index_changed"` row to the PubSub Topics table (topic: `"records:index_changed"`, message: `:records_index_changed`, used by: CollectionLive.Index, WishlistLive.Index) |
| `.agents/skills/oban-worker/SKILL.md`  | No changes needed — existing patterns unchanged                                                                                                                                       |
| `.agents/skills/ui-framework/SKILL.md` | No changes needed — existing patterns unchanged                                                                                                                                       |

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

# Implementation Plan — Route A (Revised)

## Objective Alignment

When background import Oban jobs complete, the collection and wishlist index pages must automatically show new records without requiring a manual refresh. Broadcast a PubSub event from import workers after success; index LiveViews subscribe and reload their streams.

## Implementation Steps

### Step 1: Add `broadcast_index_changed/0` to Records context

**File**: `lib/music_library/records.ex`

```elixir
def broadcast_index_changed do
  Phoenix.PubSub.broadcast(MusicLibrary.PubSub, "records:index_changed", :records_index_changed)
end
```

Simple PubSub wrapper. No schema or DB changes.

### Step 2: Add `subscribe_to_index/0` to Records context

**File**: `lib/music_library/records.ex`

```elixir
def subscribe_to_index do
  Phoenix.PubSub.subscribe(MusicLibrary.PubSub, "records:index_changed")
end
```

### Step 3: Add `handle_index_changed/1` to IndexActions

**File**: `lib/music_library_web/live_helpers/index_actions.ex`

**Critical**: Must refresh `total_entries` (via `search_records_count`) before reloading the stream. Without this, the pagination bar shows stale page counts when records are added while browsing.

```elixir
def handle_index_changed(socket) do
  config = socket.assigns.index_config
  params = socket.assigns.record_list_params
  total_records = config.context_module.search_records_count(params.query)
  updated_params = %{params | total_entries: total_records}
  load_and_assign_records(socket, updated_params)
end
```

Both `search_records_count/2` and `load_and_assign_records/2` already exist as public functions on each context module.

### Step 4: Subscribe in CollectionLive.Index

**File**: `lib/music_library_web/live/collection_live/index.ex`

Add `Records.subscribe_to_index()` in `mount/3` (only when `connected?(socket)`). Add guarded `handle_info`:

```elixir
def handle_info(:records_index_changed, socket) when socket.assigns.live_action in [:index, :edit] do
  {:noreply, IndexActions.handle_index_changed(socket)}
end

def handle_info(:records_index_changed, socket), do: {:noreply, socket}
```

Guard rationale: on `:import` / `:barcode_scan` the grid is behind a modal — reload would waste a query and flicker the modal title. Only `:index` / `:edit` have the grid visible. Returning from sub-route triggers `handle_params` → fresh load anyway.

### Step 5: Subscribe in WishlistLive.Index

**File**: `lib/music_library_web/live/wishlist_live/index.ex`

Same pattern as Step 4. Guard on `:index` and `:edit` only.

### Step 6: Call `broadcast_index_changed/0` from import workers

**Files**: `lib/music_library/worker/import_from_musicbrainz_release.ex`, `lib/music_library/worker/import_from_musicbrainz_release_group.ex`

After `{:ok, _record}` match, insert `Records.broadcast_index_changed()` before `:ok`.

### Step 7: Write tests

1. `records_test.exs`: Subscribe, broadcast, assert_receive `:records_index_changed`.
2. `import_from_musicbrainz_release_test.exs`: Subscribe before `perform_job`, assert_receive after success.
3. `import_from_musicbrainz_release_group_test.exs`: Same pattern.
4. **LiveView tests**: Mount index as `:index`, send `:records_index_changed`, verify stream reloaded AND `record_list_params.total_entries` refreshed. Also verify no-op when `live_action` is `:import`.
5. **Manual browser**: Import 2+ records via cart and barcode scan. Confirm auto-update on both indexes, no modal title flicker, pagination bar reflects new total count.

---

## Design Decisions & Tradeoffs

### Single topic for collection + wishlist

Workers handle both types. Single `"records:index_changed"` topic means both indexes reload — one extra FTS query on the non-matching index, negligible. Splitting adds complexity for no gain.

### Guard on `live_action`

Prevents `page_title` flicker in modals during background import. Only reloads when grid is visible (`:index`, `:edit`).

### Offset pagination and index change reloads

The project uses offset-based pagination (`LIMIT ? OFFSET ?`). When `handle_index_changed` reloads, newly-inserted records shift existing records by sort position. If the user is on page 2+ when a background import completes, the page content may shift slightly (records from page 1 slide in, records from the end slide to page 3). Step 3's `total_entries` refresh keeps the pagination bar accurate.

**Why acceptable**: In a personal library (hundreds to low thousands of records), the window is narrow — the background job must complete _after_ the user navigated to page 2+, which is unusual. When it happens, the shift is at most the imported count (typically 1–3). Imperceptible.

**Cursor-based pagination rejected**: Keyset pagination (`WHERE column < :cursor`) would eliminate offset-shift but requires composite cursors per sort order, breaks numbered-page UI, complicates FTS5 joins, and doubles SQL for reverse navigation. A 2-week refactor vs. a 5-line fix — not warranted at this scale.

### Double-reload on async import (harmless)

`handle_cart_imported_async` pushes to base path → `handle_params` → full load. Worker completion triggers a second load via PubSub. Harmless — not worth optimizing.

---

## Architecture Impact

| Touchpoint           | Impact                                                            |
| -------------------- | ----------------------------------------------------------------- |
| PubSub topic         | NEW: `"records:index_changed"` → `:records_index_changed`         |
| Records context      | +2 functions: `broadcast_index_changed/0`, `subscribe_to_index/0` |
| Import workers       | Both call `broadcast_index_changed/0` after success               |
| CollectionLive.Index | + subscription in `mount`, + guarded `handle_info`                |
| WishlistLive.Index   | Same as above                                                     |
| IndexActions         | + `handle_index_changed/1`                                        |

## Performance Profile

- **PubSub**: O(1), max 2 subscribers. Dead subscribers auto-cleaned.
- **Queries per refresh**: `search_records_count` (lightweight COUNT) + `search_records` (FTS5 join with LIMIT/OFFSET). Same cost as any search/sort action.
- **Throttling**: Workers rate-limited by `:music_brainz` queue (concurrency: 1).
- **Guarded**: Skipped on sub-routes (`:import`, `:barcode_scan`).

## Documentation Updates

- `docs/architecture.md`: Add `"records:index_changed"` to PubSub Topics table.
<!-- SECTION:NOTES:END -->
