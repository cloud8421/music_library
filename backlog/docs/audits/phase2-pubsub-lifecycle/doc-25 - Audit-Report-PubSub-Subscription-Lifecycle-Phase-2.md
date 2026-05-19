---
id: doc-25
title: "Audit Report: PubSub Subscription Lifecycle (Phase 2)"
type: other
created_date: "2026-05-19 07:16"
tags:
  - audit
  - pubsub
  - subscribe
  - liveview
  - reconnect
---

# Phase 2 PubSub Audit: Subscription Lifecycle

**Date:** 2026-05-19
**Scope:** All `Phoenix.PubSub.subscribe/2`, `unsubscribe/2`, `broadcast/3` call sites matched against consumers and navigation paths. Reconnect/death lifecycle verified against Phoenix.PubSub and LiveView behavior.

## Executive Summary

**Result: PASS — No bugs or stale subscriptions found.** All 8 subscribe sites have correct unsubscribe or auto-cleanup coverage. The pre-flagged `ListeningStats.subscribe()` double-subscription concern is a false positive: Phoenix.PubSub internally deduplicates per PID, and LiveView reconnect reuses the same PID within the grace period.

---

## PubSub Topic Inventory

| Topic                      | Subscribe (lines)                                                                       | Unsubscribe (lines)                       | Broadcast (lines)                                | Consumers (lines)                                               |
| -------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------- |
| `"records:#{id}"`          | `records.ex:109`, `record_actions.ex:108`                                               | `records.ex:117`, `record_actions.ex:107` | `records.ex:123` via `notify_update/1`           | `collection_live/show.ex:474`, `wishlist_live/show.ex:367`      |
| `"records:index_changed"`  | `records.ex:143`, `collection_live/index.ex:247`, `wishlist_live/index.ex:180`          | (auto-clean on PID death)                 | `records.ex:136` via `broadcast_index_changed/0` | `collection_live/index.ex:308`, `wishlist_live/index.ex:224`    |
| `"listening_stats:update"` | `listening_stats.ex:74`, `stats_live/index.ex:80`, `scrobbled_tracks_live/index.ex:235` | (auto-clean on PID death)                 | `listening_stats.ex:67`                          | `stats_live/index.ex:176`, `scrobbled_tracks_live/index.ex:281` |

---

## Acceptance Criterion #1: Records.subscribe/1 and unsubscribe/1 Call Sites

**Status: ✅ CONFIRMED — only called via manage_subscription/2 in Show LiveViews.**

### Subscribe call sites

| Source                      | File                | Line | Context                        |
| --------------------------- | ------------------- | ---- | ------------------------------ |
| `Records.subscribe/1` (def) | `records.ex`        | 109  | Function definition            |
| `Records.subscribe(new_id)` | `record_actions.ex` | 108  | Inside `manage_subscription/2` |

### Unsubscribe call sites

| Source                           | File                | Line | Context                        |
| -------------------------------- | ------------------- | ---- | ------------------------------ |
| `Records.unsubscribe/1` (def)    | `records.ex`        | 117  | Function definition            |
| `Records.unsubscribe(record.id)` | `record_actions.ex` | 107  | Inside `manage_subscription/2` |

### Callers of manage_subscription/2

| LiveView            | File                                                 | Line | Hook              |
| ------------------- | ---------------------------------------------------- | ---- | ----------------- |
| CollectionLive.Show | `lib/music_library_web/live/collection_live/show.ex` | 361  | `handle_params/3` |
| WishlistLive.Show   | `lib/music_library_web/live/wishlist_live/show.ex`   | 298  | `handle_params/3` |

**Verification:** Grep for `Records.subscribe` and `Records.unsubscribe` across `lib/` (excluding tests) returns only the definition in `records.ex` and the calls in `record_actions.ex`. No raw subscribe/unsubscribe bypass exists anywhere.

---

## Acceptance Criterion #2: manage_subscription/2 Navigation Correctness

**Status: ✅ VERIFIED — correct across all navigation paths.**

### Path coverage analysis

| Navigation scenario                    | Lifecycle                                         | Behavior                                                                                              | Correct? |
| -------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | -------- |
| Direct URL load                        | `mount` → `handle_params`                         | `socket.assigns[:record]` is nil → subscribes only (no old record)                                    | ✅       |
| `push_navigate` to record              | `handle_params` fires with new ID                 | Unsubscribes old → subscribes new                                                                     | ✅       |
| `push_patch` to record                 | `handle_params` fires with new ID                 | Same as push_navigate                                                                                 | ✅       |
| Browser back/forward                   | `handle_params` fires (LiveView handles popstate) | Same as push_navigate                                                                                 | ✅       |
| LiveView reconnect (same page)         | `mount` → `handle_params` (same PID)              | Unsubscribes old → resubscribes same record. PubSub MapSet deduplicates PID, so it's a harmless no-op | ✅       |
| LiveView reconnect (timeout → new PID) | Old PID dies → auto-cleanup → new mount           | New PID subscribes fresh. No overlap.                                                                 | ✅       |

### Code path analysis

```elixir
# lib/music_library_web/live_helpers/record_actions.ex:105-109
def manage_subscription(socket, new_id) do
  if Phoenix.LiveView.connected?(socket) do
    if socket.assigns[:record], do: Records.unsubscribe(socket.assigns.record.id)
    Records.subscribe(new_id)
  end
  :ok
end
```

- **connected?(socket) guard:** Prevents subscribing during static/dead render. Subscription only happens when the WebSocket is connected. ✅
- **nil-safe unsubscribe:** Uses `socket.assigns[:record]` (access syntax) not `socket.assigns.record` (raises on nil). First mount with no record is safe. ✅
- **Called before record fetch:** `manage_subscription` is called at the top of `handle_params`, before `Records.get_record!(id)`. This means `socket.assigns[:record]` still holds the _old_ record (from the previous `handle_params` call), which is the correct one to unsubscribe from. ✅

---

## Acceptance Criterion #3: ListeningStats.subscribe() Reconnect Risk

**Status: ✅ CONFIRMED SAFE — no double-subscription risk.**

### Pre-flagged concern

`ListeningStats.subscribe()` is called in `mount/3` by `StatsLive.Index` and `ScrobbledTracksLive.Index` but is never explicitly unsubscribed.

### Why this is safe

**1. Phoenix.PubSub internal deduplication**

Phoenix.PubSub maintains a MapSet of PIDs per topic. Subscribing the same PID to the same topic twice is a no-op. Source: [Phoenix.PubSub docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html#subscribe/2).

```elixir
# This is harmless on reconnect — the PID is already in the topic's MapSet
ListeningStats.subscribe()  # no-op on same PID for same topic
```

**2. LiveView reconnect reuses the same PID**

When a WebSocket disconnects, Phoenix LiveView keeps the process alive for a configurable reconnect timeout (default 60s in this project). If the client reconnects within this window, `mount/3` is called on the **same PID**. Since the PID is already subscribed, the second `subscribe` call is a no-op.

**3. PID death cleans up subscriptions**

If the LiveView crashes or the reconnect timeout expires, the process dies. Phoenix.PubSub's process monitor (`:erlang.monitor/2`) automatically removes the PID from all topic MapSets. A new connection spawns a new PID with a fresh subscription.

**4. connected?(socket) guard prevents dead-render subscription**

```elixir
# stats_live/index.ex:79-81
if connected?(socket) do
  ListeningStats.subscribe()
end
```

No subscription is created during the initial static render (dead mount).

### Reconnect sequence diagram

```
Scenario: WebSocket drops, client reconnects within 60s

  PID-1 subscribes to "listening_stats:update"  (mount)
    ↓
  WebSocket disconnects
  PID-1 stays alive (waiting for reconnect)
  PubSub retains PID-1 in topic MapSet
    ↓
  Client reconnects within 60s
  mount/3 called on PID-1
  ListeningStats.subscribe() called again
  PubSub: PID-1 already in MapSet → no-op
    ↓
  Result: single subscription for PID-1 ✅


Scenario: LiveView crashes hard

  PID-1 subscribes to "listening_stats:update"  (mount)
    ↓
  PID-1 crashes
  PubSub auto-removes PID-1 from topic MapSet
    ↓
  Supervisor restarts LiveView → PID-2 spawns
  mount/3 called on PID-2
  ListeningStats.subscribe() called
    ↓
  Result: single subscription for PID-2 ✅
```

---

## Acceptance Criterion #4: Termination Cleanup

**Status: ✅ VERIFIED — PID death covers all cleanup. No manual gaps.**

### Cleanup mechanism

Phoenix.PubSub uses `Process.monitor/1` to track subscriber PIDs. When a process exits (gracefully or crashes), the monitor fires and Phoenix.PubSub removes all of that PID's subscriptions. No explicit `unsubscribe` in `terminate/2` is needed.

### Per-topic cleanup summary

| Topic                      | Subscribers                                | Manual unsubscribe?                                      | PID-death cleanup? | Gap? |
| -------------------------- | ------------------------------------------ | -------------------------------------------------------- | ------------------ | ---- |
| `"records:#{id}"`          | CollectionLive.Show, WishlistLive.Show     | Yes — `manage_subscription/2` unsubscribes on navigation | Yes — covers crash | None |
| `"records:index_changed"`  | CollectionLive.Index, WishlistLive.Index   | No                                                       | Yes                | None |
| `"listening_stats:update"` | StatsLive.Index, ScrobbledTracksLive.Index | No                                                       | Yes                | None |

### Design note

Adding `Phoenix.PubSub.unsubscribe(MusicLibrary.PubSub, "...")` to `on_mount/2` or a LiveView `terminate/2` would make the cleanup explicit, but this would be defensive coding against a mechanism that already works correctly. **No change recommended.**

---

## Acceptance Criterion #5: notify_update/1 Broadcast Sites

**Status: ✅ VERIFIED — correctly scoped and consumed.**

### Broadcast producers

All broadcasts go to `"records:#{record.id}"` with message `{:update, record}`.

| Worker                                | File                                                           | Line | Trigger                                            |
| ------------------------------------- | -------------------------------------------------------------- | ---- | -------------------------------------------------- |
| `Worker.GenerateRecordEmbedding`      | `lib/music_library/worker/generate_record_embedding.ex`        | 16   | After embedding generation completes               |
| `Worker.PopulateGenres`               | `lib/music_library/worker/populate_genres.ex`                  | 15   | After genres populated + embedding generated async |
| `Worker.RecordRefreshMusicBrainzData` | `lib/music_library/worker/record_refresh_music_brainz_data.ex` | 14   | After MusicBrainz data refresh                     |
| `Worker.RefreshCover`                 | `lib/music_library/worker/refresh_cover.ex`                    | 14   | After cover image refreshed/resized                |

### Broadcast consumers

```elixir
# collection_live/show.ex:474-483
def handle_info({:update, record}, socket) do
  if record.id == socket.assigns.record.id do
    {:noreply, socket |> RecordActions.handle_record_updated(record) |> assign_similar_records()}
  else
    {:noreply, socket}
  end
end

# wishlist_live/show.ex:367-373
def handle_info({:update, record}, socket) do
  if record.id == socket.assigns.record.id do
    {:noreply, RecordActions.handle_record_updated(socket, record)}
  else
    {:noreply, socket}
  end
end
```

**Guard clause analysis:** Both consumers verify `record.id == socket.assigns.record.id` before applying the update. This prevents a Show LiveView displaying record A from being updated by a worker that modified record B. ✅

**Topic scoping:** Since the topic is `"records:#{record.id}"`, only LiveViews subscribed to that specific record's topic will receive the broadcast. A Show LiveView for record A never receives updates for record B. ✅

### broadcast_index_changed/0

| Producer                                   | File                                                                | Line | Trigger                |
| ------------------------------------------ | ------------------------------------------------------------------- | ---- | ---------------------- |
| `Worker.ImportFromMusicbrainzRelease`      | `lib/music_library/worker/import_from_musicbrainz_release.ex`       | 24   | After import completes |
| `Worker.ImportFromMusicbrainzReleaseGroup` | `lib/music_library/worker/import_from_musicbrainz_release_group.ex` | 27   | After import completes |

**Consumers** (both with guard clause):

```elixir
# collection_live/index.ex:308-313
def handle_info(:records_index_changed, socket)
    when socket.assigns.live_action in [:index, :edit] do
  {:noreply, IndexActions.handle_index_changed(socket)}
end

def handle_info(:records_index_changed, socket), do: {:noreply, socket}
```

The guard clause `when socket.assigns.live_action in [:index, :edit]` prevents index refresh when the user is on the import modal or scanning barcodes — these actions have their own lifecycle. ✅

---

## Complete Call Site Matrix

| #   | File:Line                                     | Call                                        | Category              | Verified? |
| --- | --------------------------------------------- | ------------------------------------------- | --------------------- | --------- |
| 1   | `records.ex:109-110`                          | `subscribe/1` def                           | Definition            | ✅        |
| 2   | `records.ex:117-118`                          | `unsubscribe/1` def                         | Definition            | ✅        |
| 3   | `records.ex:122-127`                          | `notify_update/1` via `broadcast`           | Broadcast             | ✅        |
| 4   | `records.ex:135-136`                          | `broadcast_index_changed/0` via `broadcast` | Broadcast             | ✅        |
| 5   | `records.ex:143-144`                          | `subscribe_to_index/0` def                  | Definition            | ✅        |
| 6   | `listening_stats.ex:67`                       | `broadcast` in `update/1`                   | Broadcast             | ✅        |
| 7   | `listening_stats.ex:73-74`                    | `subscribe/0` def                           | Definition            | ✅        |
| 8   | `record_actions.ex:107`                       | `unsubscribe` in `manage_subscription`      | Unsubscribe           | ✅        |
| 9   | `record_actions.ex:108`                       | `subscribe` in `manage_subscription`        | Subscribe             | ✅        |
| 10  | `collection_live/index.ex:247`                | `subscribe_to_index` in mount               | Subscribe             | ✅        |
| 11  | `collection_live/show.ex:361`                 | `manage_subscription`                       | Subscribe/Unsubscribe | ✅        |
| 12  | `wishlist_live/index.ex:180`                  | `subscribe_to_index` in mount               | Subscribe             | ✅        |
| 13  | `wishlist_live/show.ex:298`                   | `manage_subscription`                       | Subscribe/Unsubscribe | ✅        |
| 14  | `stats_live/index.ex:80`                      | `subscribe` in mount                        | Subscribe             | ✅        |
| 15  | `scrobbled_tracks_live/index.ex:235`          | `subscribe` in mount                        | Subscribe             | ✅        |
| 16  | `collection_live/show.ex:474`                 | `handle_info({:update, record}, ...)`       | Consumer              | ✅        |
| 17  | `wishlist_live/show.ex:367`                   | `handle_info({:update, record}, ...)`       | Consumer              | ✅        |
| 18  | `collection_live/index.ex:308`                | `handle_info(:records_index_changed, ...)`  | Consumer              | ✅        |
| 19  | `wishlist_live/index.ex:224`                  | `handle_info(:records_index_changed, ...)`  | Consumer              | ✅        |
| 20  | `stats_live/index.ex:167,176`                 | `handle_info(%{track_count: _}, ...)`       | Consumer              | ✅        |
| 21  | `scrobbled_tracks_live/index.ex:281,286`      | `handle_info(%{track_count: _}, ...)`       | Consumer              | ✅        |
| 22  | `generate_record_embedding.ex:16`             | `notify_update`                             | Broadcast             | ✅        |
| 23  | `populate_genres.ex:15`                       | `notify_update`                             | Broadcast             | ✅        |
| 24  | `record_refresh_music_brainz_data.ex:14`      | `notify_update`                             | Broadcast             | ✅        |
| 25  | `refresh_cover.ex:14`                         | `notify_update`                             | Broadcast             | ✅        |
| 26  | `import_from_musicbrainz_release.ex:24`       | `broadcast_index_changed`                   | Broadcast             | ✅        |
| 27  | `import_from_musicbrainz_release_group.ex:27` | `broadcast_index_changed`                   | Broadcast             | ✅        |

---

## Recommendations

| #   | Finding                                                                                                                                 | Severity | Recommendation                                                                                                                                                       |
| --- | --------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | No explicit `unsubscribe` in LiveView `terminate/2` for index or listening_stats subscriptions                                          | ℹ️ Info  | Not needed — PID death auto-cleans. Adding would be defensive but offers no functional benefit.                                                                      |
| 2   | `manage_subscription/2` redundantly unsubscribes+resubscribes on LiveView reconnect to the same record                                  | ℹ️ Info  | Harmless no-op (PubSub deduplicates by PID). A same-record check (`if socket.assigns[:record] && socket.assigns.record.id != new_id`) would be a micro-optimization. |
| 3   | `Records.notify_update/1` broadcasts `record` struct over PubSub — contains all fields including potentially large ones (cover binary?) | ℹ️ Info  | Struct is already loaded from DB by the worker, and the struct is small (references, not blobs). Covers are stored on disk, not in the struct. No concern.           |

**No issues require code changes.**
