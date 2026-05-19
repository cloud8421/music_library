---
id: doc-24
title: "Audit Report: LiveComponent → Parent handle_info Coverage (Phase 1)"
type: other
created_date: "2026-05-19 06:35"
tags:
  - audit
  - liveview
  - handle_info
  - components
---

# Phase 1 Async Message Audit: LiveComponent → Parent handle_info Coverage

**Date:** 2026-05-19
**Scope:** All `send(self(), ...)` call sites in LiveComponents matched against `handle_info` clauses in parent LiveViews.

## Executive Summary

**Result: PASS — No critical bugs found.** All 11 message-producing components have their messages properly handled by their parent LiveViews. The pre-flagged Release component concern was a false positive — the component safely skips sending when `on_release_loaded` is nil.

---

## Complete Producer → Consumer Matrix

### Components (lib/music_library_web/components/)

#### 1. RecordForm (`MusicLibraryWeb.Components.RecordForm`)

- **File:** `lib/music_library_web/components/record_form.ex`
- **Send pattern:** `send(self(), {__MODULE__, {:saved, record}})` (lines 564, 603)
- **Consumers:**

| LiveView             | File                                                  | Line     | Message             | Status                     |
| -------------------- | ----------------------------------------------------- | -------- | ------------------- | -------------------------- |
| CollectionLive.Show  | `lib/music_library_web/live/collection_live/show.ex`  | 338, 461 | `{:saved, record}`  | ✅ Full match              |
| CollectionLive.Index | `lib/music_library_web/live/collection_live/index.ex` | 177, 291 | `{:saved, _record}` | ✅ Match (ignores payload) |
| WishlistLive.Show    | `lib/music_library_web/live/wishlist_live/show.ex`    | 274, 355 | `{:saved, record}`  | ✅ Full match              |
| WishlistLive.Index   | `lib/music_library_web/live/wishlist_live/index.ex`   | 144, 212 | `{:saved, _record}` | ✅ Match (ignores payload) |

#### 2. AddRecord (`MusicLibraryWeb.Components.AddRecord`)

- **File:** `lib/music_library_web/components/add_record.ex`
- **Send pattern:** `send(self(), {__MODULE__, msg})` (line 574)
- **Messages:** `{:imported_single, record}` (line 452), `{:imported_async, count}` (line 435)
- **Consumers:**

| LiveView             | File                                                  | Line          | Message       | Status |
| -------------------- | ----------------------------------------------------- | ------------- | ------------- | ------ |
| CollectionLive.Index | `lib/music_library_web/live/collection_live/index.ex` | 193, 295, 299 | Both messages | ✅     |
| WishlistLive.Index   | `lib/music_library_web/live/wishlist_live/index.ex`   | 160, 216, 220 | Both messages | ✅     |

#### 3. Chat (`MusicLibraryWeb.Components.Chat`)

- **File:** `lib/music_library_web/components/chat.ex`
- **Send pattern:** `send(self(), {__MODULE__, :chats_changed})` (lines 344, 431)
- **Consumers:**

| LiveView             | File                                                  | Line     | Message          | Status |
| -------------------- | ----------------------------------------------------- | -------- | ---------------- | ------ |
| CollectionLive.Show  | `lib/music_library_web/live/collection_live/show.ex`  | 322, 469 | `:chats_changed` | ✅     |
| CollectionLive.Index | `lib/music_library_web/live/collection_live/index.ex` | 225, 303 | `:chats_changed` | ✅     |
| WishlistLive.Show    | `lib/music_library_web/live/wishlist_live/show.ex`    | 258, 362 | `:chats_changed` | ✅     |
| ArtistLive.Show      | `lib/music_library_web/live/artist_live/show.ex`      | 477, 630 | `:chats_changed` | ✅     |

#### 4. Release (`MusicLibraryWeb.Components.Release`)

- **File:** `lib/music_library_web/components/release.ex`
- **Send pattern:** `send(self(), {tag, release})` (line 82) — **non-MODULE pattern**
- **Consumers:**

| LiveView                 | File                                                       | Line   | on_release_loaded   | handle_info                                    | Status      |
| ------------------------ | ---------------------------------------------------------- | ------ | ------------------- | ---------------------------------------------- | ----------- |
| ScrobbleLive.ReleaseShow | `lib/music_library_web/live/scrobble_live/release_show.ex` | 41, 68 | `{:release_loaded}` | `handle_info({:release_loaded, release}, ...)` | ✅          |
| CollectionLive.Show      | `lib/music_library_web/live/collection_live/show.ex`       | 304    | (not set = nil)     | N/A — no message sent                          | ✅ Harmless |

**CollectionLive.Show analysis:** The component's `notify_release_loaded/2` checks `socket.assigns[:on_release_loaded]` before sending. When nil (as in CollectionLive.Show), it returns `:ok` without calling `send/2`. This is intentional — CollectionLive.Show doesn't need to react to release loading. **No dead message, no missing handler.**

#### 5. ScrobbleRulePicker (`MusicLibraryWeb.ScrobbleRulePicker`)

- **File:** `lib/music_library_web/components/scrobble_rule_picker.ex`
- **Send pattern:** `send(self(), {__MODULE__, {:rule_created, rule}})` (line 191/212)
- **Consumers:**

| LiveView                  | File                                                        | Line     | Status |
| ------------------------- | ----------------------------------------------------------- | -------- | ------ |
| ScrobbledTracksLive.Index | `lib/music_library_web/live/scrobbled_tracks_live/index.ex` | 215, 283 | ✅     |
| StatsLive.Index           | `lib/music_library_web/live/stats_live/index.ex`            | 57, 167  | ✅     |

Note: Not rendered in ScrobbleRulesLive.Index — that LiveView only uses ScrobbleRulesLive.Form.

---

### Form Components (lib/music_library_web/live/\*/form.ex)

#### 6. ArtistLive.Form (`MusicLibraryWeb.ArtistLive.Form`)

- **File:** `lib/music_library_web/live/artist_live/form.ex`
- **Messages:** `{:saved, artist_info}` (lines 279, 319)
- **Consumer:** `artist_live/show.ex:493, 639` ✅

#### 7. RecordSetLive.Form (`MusicLibraryWeb.RecordSetLive.Form`)

- **File:** `lib/music_library_web/live/record_set_live/form.ex`
- **Messages:** `{:updated, record_set}` (line 74), `{:created, record_set}` (line 87)
- **Consumers:**

| LiveView            | File                                                  | Lines        | Messages handled        | Status                                                                                  |
| ------------------- | ----------------------------------------------------- | ------------ | ----------------------- | --------------------------------------------------------------------------------------- |
| RecordSetLive.Show  | `lib/music_library_web/live/record_set_live/show.ex`  | 185, 227     | `:updated` only         | ✅ Correct — Show only renders Form in `:edit` mode (line 180: `@live_action == :edit`) |
| RecordSetLive.Index | `lib/music_library_web/live/record_set_live/index.ex` | 94, 192, 199 | `:created` + `:updated` | ✅                                                                                      |

#### 8. RecordSetLive.RecordPicker (`MusicLibraryWeb.RecordSetLive.RecordPicker`)

- **File:** `lib/music_library_web/live/record_set_live/record_picker.ex`
- **Message:** `{:added, updated_set}` (line 191)
- **Consumers:**
  - `record_set_live/show.ex:201, 237` ✅
  - `record_set_live/index.ex:108, 206` ✅

#### 9. ScrobbleRulesLive.Form (`MusicLibraryWeb.ScrobbleRulesLive.Form`)

- **File:** `lib/music_library_web/live/scrobble_rules_live/form.ex`
- **Messages:** `{:updated, scrobble_rule}` (line 93), `{:created, scrobble_rule}` (line 106)
- **Consumer:** `scrobble_rules_live/index.ex:249, 259` ✅

#### 10. ScrobbledTracksLive.Form (`MusicLibraryWeb.ScrobbledTracksLive.Form`)

- **File:** `lib/music_library_web/live/scrobbled_tracks_live/form.ex`
- **Message:** `{:saved, track}` (line 109)
- **Consumer:** `scrobbled_tracks_live/index.ex:271` ✅

#### 11. OnlineStoreTemplateLive.Form (`MusicLibraryWeb.OnlineStoreTemplateLive.Form`)

- **File:** `lib/music_library_web/live/online_store_template_live/form.ex`
- **Message:** `{:saved, template}` (lines 117, 130)
- **Consumer:** `online_store_template_live/index.ex:199` ✅

---

## Non-MODULE Pattern Audit (Acceptance Criterion #4)

Three non-`{__MODULE__, _}` patterns were found:

1. **Release component** (`release.ex:82`) — `send(self(), {tag, release})` where tag is a dynamic assign
   - **Severity:** LOW — design note only
   - **Status:** Correctly handled in ScrobbleLive.ReleaseShow; safely no-ops in CollectionLive.Show
   - **Risk:** If a new consumer sets a non-atom tag (e.g., a string), pattern matching could fail silently. The `handle_info` clauses pattern-match on atoms (`:release_loaded`).
   - **Recommendation:** Consider using `{__MODULE__, {:loaded, release}}` for type safety, but not required.

2. **ScrobbleLive.Index** (`scrobble_live/index.ex:123,139`) — `send(self(), {:perform_search, query})`
   - **Severity:** INFO — self-send within same LiveView, not a component→parent message
   - **Status:** Has matching `handle_info({:perform_search, query}, ...)` at line 145 ✅

3. **ShowToast hook** (`hooks/show_toast.ex:8`) — `send(self(), {:put_toast, type, message})`
   - **Severity:** N/A — standard LiveView `attach_hook` pattern
   - **Status:** Intercepted by `maybe_put_toast/2` hook before reaching `handle_info` ✅

---

## handle_info Clauses Without Corresponding Component Sends

These `handle_info` clauses exist in LiveViews but receive messages from non-component sources (PubSub broadcast, Phoenix channels):

| LiveView                  | Message                  | Source                                         |
| ------------------------- | ------------------------ | ---------------------------------------------- |
| CollectionLive.Index      | `:records_index_changed` | PubSub from Records context                    |
| WishlistLive.Index        | `:records_index_changed` | PubSub from Records context                    |
| CollectionLive.Show       | `{:update, record}`      | PubSub from Records context (`records.ex:126`) |
| WishlistLive.Show         | `{:update, record}`      | PubSub from Records context (`records.ex:126`) |
| ScrobbledTracksLive.Index | `%{track_count: _}`      | PubSub from ScrobbleActivity context           |
| StatsLive.Index           | `%{track_count: _}`      | PubSub from ScrobbleActivity context           |
| MaintenanceLive.Index     | `:update_job_counts`     | Self-send or timer                             |

These are all correctly handled and outside the scope of this component audit.

---

## Coverage Statistics

- **11/11 components verified** ✅
- **14 send(self()) call sites** across all components
- **22 handle_info clauses** in parent LiveViews matching component messages
- **0 missing handlers** found
- **0 dead messages** found
- **3 non-MODULE patterns** — all verified safe

---

## Recommendations

1. **LOW:** The Release component's dynamic tag pattern (`send(self(), {tag, release})`) works correctly but could be made type-safe by using `{__MODULE__, {:loaded, release}}` with a static atom. This would prevent accidental non-atom tags and make message tracing easier. **Not blocking.**

2. **INFO:** All `.ex` form components under `lib/music_library_web/live/*/form.ex` follow an identical `notify_parent/1` → `{__MODULE__, msg}` pattern. This is consistent and well-structured. **No changes needed.**

3. **INFO:** The `RecordSetLive.Show` only handles `{:updated, ...}` from `RecordSetLive.Form` — this is correct because the Show LiveView only renders the Form in `:edit` mode. No missing handler. **No changes needed.**
