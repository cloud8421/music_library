---
id: ML-169
title: "Comprehensive application audit: functional correctness and performance"
status: To Do
assignee: []
created_date: "2026-05-08 08:46"
updated_date: "2026-05-11 06:46"
labels:
  - audit
dependencies: []
references:
  - docs/architecture.md
  - docs/project-conventions.md
  - >-
    backlog/tasks/ml-168 -
    Update-wishlist-index-and-collection-index-when-background-import-finishes.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Large-scale audit of the application covering two dimensions:

**1. Functional Issues**: Unhandled async messages from LiveComponents, stale PubSub subscriptions, unexpected state changes from concurrent operations (background workers updating records while user is viewing them).

**2. Performance Low-Hanging Fruit**: Unnecessary server round trips, missing opportunities for optimistic updates, redundant data reloads, and synchronous blocking work in mount.

The audit is divided into 4 independent phases that can be tackled in parallel or sequentially. Each phase produces findings that feed into fix tasks. Full implementation plan in the task plan section.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Phase 1 (async messages): all LiveComponents that send messages to parent LiveViews have matching handle_info clauses documented; missing handlers identified with severity
- [ ] #2 Phase 2 (PubSub lifecycle): all subscribe/unsubscribe pairs verified correct; stale subscription risks identified; ML-168 gap separately accounted for
- [ ] #3 Phase 3 (state change safety): concurrent record-mutation patterns audited; {:update, record} guards and manage_subscription patterns verified across all navigation paths
- [ ] #4 Phase 4 (performance): unnecessary round trips, redundant full-stream reloads, and synchronous mount work identified with estimated impact and fix approach
- [ ] #5 Each phase produces a written finding report with file paths, line references, severity ratings, and recommended fixes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Audit Implementation Plan

## Audit Scope

This audit covers all 14 LiveViews, all LiveComponents that send messages to parents, all PubSub subscription points, and all Oban worker-LiveView interaction patterns. The full architecture is documented in `docs/architecture.md`.

## Phase Structure

Each phase is a standalone investigation that produces a findings document. Fixes are NOT implemented in these phases — only identification, severity rating, and fix recommendations.

---

## Phase 1: Async Message Audit (LiveComponent → Parent)

**Goal**: Verify every LiveComponent message has a matching `handle_info` in its parent LiveView.

**Known message producers and their parents**:

| Component                      | Messages sent                                            | Consumer LiveViews                                                               | Status                                                                                                      |
| ------------------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `RecordForm`                   | `{:saved, record}`                                       | CollectionLive.Index, WishlistLive.Index, CollectionLive.Show, WishlistLive.Show | ✅ All four have handlers                                                                                   |
| `AddRecord`                    | `{:imported_single, record}`, `{:imported_async, count}` | CollectionLive.Index, WishlistLive.Index                                         | ✅ Both have handlers                                                                                       |
| `Chat`                         | `:chats_changed`                                         | CollectionLive.Index, CollectionLive.Show, WishlistLive.Show, ArtistLive.Show    | ✅ All four have handlers                                                                                   |
| `Release`                      | `{tag, release}` (dynamic tag)                           | ScrobbleLive.ReleaseShow, CollectionLive.Show                                    | ⚠️ CollectionLive.Show renders Release but has NO `handle_info({:release_loaded, _})` — needs investigation |
| `ArtistLive.Form`              | `{:saved, artist_info}`                                  | ArtistLive.Show                                                                  | ✅ Has handler                                                                                              |
| `RecordSetLive.Form`           | `{:created, _}`, `{:updated, _}`                         | RecordSetLive.Index                                                              | ✅ Has handlers                                                                                             |
| `RecordSetLive.RecordPicker`   | `{:added, record_set}`                                   | RecordSetLive.Index                                                              | ✅ Has handler                                                                                              |
| `ScrobbleRulesLive.Form`       | `{:created, _}`, `{:updated, _}`                         | ScrobbleRulesLive.Index                                                          | ✅ Has handlers                                                                                             |
| `ScrobbledTracksLive.Form`     | `{:saved, _track}`                                       | ScrobbledTracksLive.Index                                                        | ✅ Has handler                                                                                              |
| `OnlineStoreTemplateLive.Form` | `{:saved, template}`                                     | OnlineStoreTemplateLive.Index                                                    | ✅ Has handler                                                                                              |
| `ScrobbleRulePicker`           | `{:rule_created, _rule}`                                 | ScrobbledTracksLive.Index, StatsLive.Index                                       | ✅ Both have handlers                                                                                       |

**Investigation steps**:

1. Cross-reference every `send(self(), ...)` call site (found via `grep -rn "send(self()"`) with `handle_info` clauses in the parent LiveView
2. Specifically trace the `Release` component usage in `CollectionLive.Show` — it renders `Release` with `on_release_loaded={:release_loaded}`, but `CollectionLive.Show` has no `handle_info({:release_loaded, _})` clause. Determine if this is a dead message or a missing handler
3. Verify no component sends messages when rendered in a context that doesn't handle them (e.g., modal closed, wrong live_action)
4. Look for `send/2` calls using patterns NOT matching `{__MODULE__, _}`

**Files to check**: All `lib/music_library_web/components/*.ex`, all `lib/music_library_web/live/**/*.ex`

---

## Phase 2: PubSub Subscription Lifecycle Audit

**Goal**: Verify all PubSub subscriptions are properly paired with unsubscriptions; identify stale subscription risks.

**Subscription inventory**:

| Subscribe                    | Topic                      | Where                                                                | Unsubscribe                                                                                             | Risk                                                                                  |
| ---------------------------- | -------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `Records.subscribe(id)`      | `"records:#{id}"`          | CollectionLive.Show, WishlistLive.Show (via `manage_subscription/2`) | ✅ `manage_subscription/2` unsubscribes old ID before subscribing new — called on every `handle_params` | Low                                                                                   |
| `ListeningStats.subscribe()` | `"listening_stats:update"` | StatsLive.Index (`mount`), ScrobbledTracksLive.Index (`mount`)       | ⚠️ Never unsubscribed. Only called when connected.                                                      | Medium — PID monitoring handles cleanup but double-subscription on reconnect possible |

**Broadcast inventory**:

| Broadcast                           | Topic                      | Message             | Called from                               |
| ----------------------------------- | -------------------------- | ------------------- | ----------------------------------------- |
| `Records.notify_update/1`           | `"records:#{id}"`          | `{:update, record}` | Workers (needs audit — see Phase 3)       |
| `ListeningStats.broadcast_update/1` | `"listening_stats:update"` | `%{track_count: n}` | `lib/music_library/listening_stats.ex:68` |

**Investigation steps**:

1. Verify `manage_subscription/2` is called on ALL navigation paths: browser back/forward, direct URL, push_navigate, push_patch
2. Check that `Records.subscribe/1` is NEVER called outside of `manage_subscription/2` (only two Show LiveViews should call it)
3. Verify `ListeningStats.subscribe()` doesn't double-subscribe on LiveView reconnect (check if Phoenix.LiveView re-mounts fully or reuses process)
4. Check that `Records.unsubscribe/1` is called on terminate — currently it's only called on navigation, not process termination. Phoenix.PubSub auto-cleans when PID dies, but verify
5. Audit `Records.notify_update/1` broadcast sites against intended behavior (see Phase 3)

**Files to check**: `lib/music_library/records.ex`, `lib/music_library/listening_stats.ex`, `lib/music_library_web/live_helpers/record_actions.ex`, all Show LiveViews

---

## Phase 3: Concurrent State Change Safety Audit

**Goal**: Verify that background worker updates to records don't corrupt LiveView state.

**Pattern**: Oban worker modifies record → calls `Records.notify_update/1` → PubSub broadcasts `{:update, record}` → Show LiveView's `handle_info({:update, record}, socket)` applies update via `RecordActions.handle_record_updated/2`.

**Guard**: `record.id == socket.assigns.record.id` in both CollectionLive.Show and WishlistLive.Show ✅

**Worker-to-broadcast audit** (every worker that modifies records):

| Worker                              | Modifies record?                    | Calls notify_update? | Check                    |
| ----------------------------------- | ----------------------------------- | -------------------- | ------------------------ |
| `RefreshCover`                      | Yes — updates cover_url, cover_hash | Need to verify       | Read worker source       |
| `PopulateGenres`                    | Yes — updates genres                | Need to verify       | Read worker source       |
| `GenerateRecordEmbedding`           | Yes (indirect via Similarity)       | Need to verify       | Read worker + Similarity |
| `RecordRefreshMusicBrainzData`      | Yes — updates musicbrainz_data      | Need to verify       | Read worker source       |
| `RecordRefreshAllMusicBrainzData`   | Yes (batch)                         | Need to verify       | Read worker + Batch      |
| `RecordGenerateAllEmbeddings`       | Yes (batch)                         | Need to verify       | Read worker + Batch      |
| `ImportFromMusicbrainzRelease`      | Creates new record                  | Need to verify       | Read worker source       |
| `ImportFromMusicbrainzReleaseGroup` | Creates new records                 | Need to verify       | Read worker source       |
| `PruneAssets`                       | No (assets only)                    | N/A                  | Skip                     |
| `PruneAssetCache`                   | No (cache only)                     | N/A                  | Skip                     |
| `ApplyScrobbleRules`                | No (scrobble data)                  | N/A                  | Skip                     |
| `FetchArtistInfo`                   | No (artist info)                    | N/A                  | Skip                     |
| All `ArtistRefresh*` workers        | No (artist info)                    | N/A                  | Skip                     |
| `RefreshScrobbles`                  | No (scrobble data)                  | N/A                  | Skip                     |
| `BackfillScrobbledTracks`           | No (scrobble data)                  | N/A                  | Skip                     |
| `SendRecordsOnThisDayEmail`         | No (email)                          | N/A                  | Skip                     |
| `RepoVacuum` / `RepoOptimize`       | No (maintenance)                    | N/A                  | Skip                     |

**Additional checks**:

1. **Double-update race**: If two workers update the same record simultaneously, does the LiveView handle both `handle_info` calls correctly? (Each re-assigns `:record` — second update is latest, which is correct since workers touch different fields)
2. **Form edit + background update race**: User editing in `RecordForm` modal while a background worker updates the record. The form holds a stale `@record` assign. When the worker broadcasts `{:update, record}`, the Show page updates `socket.assigns.record`, but the form LiveComponent has its OWN `@record` assign set during `update_many`. What happens? This is a potential functional bug.
3. **ArtistLive.Show**: Does NOT handle `{:update, record}` — artist updates use a different mechanism (artist info is updated through `ArtistLive.Form` which sends `{:saved, artist_info}` directly). Verify this is intentional and complete.

**Files to check**: All `lib/music_library/worker/*.ex`, `lib/music_library/records.ex` (notify_update), `lib/music_library/records/similarity.ex`, all Show LiveViews, `RecordForm` component

---

## Phase 4: Performance Low-Hanging Fruit Audit

**Goal**: Identify unnecessary work — DB queries, stream resets, server round trips — that could be eliminated or deferred.

### 4a. Unnecessary Full-Stream Reloads

| LiveView                      | Stream name                        | Reset trigger                                                        | Optimizable?                                                                     | Impact                                   |
| ----------------------------- | ---------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------- |
| CollectionLive.Index          | `:records`                         | Every param change, form save, display toggle                        | Display toggle (grid↔list) could be CSS class only — same data, different render | Medium: 1 FTS query per toggle           |
| WishlistLive.Index            | `:records`                         | Same as above                                                        | Same                                                                             | Medium                                   |
| ScrobbleRulesLive.Index       | `:scrobble_rules`                  | Form save: does `stream_insert` then `load_and_assign_rules` (reset) | The `stream_insert` is immediately overwritten by full reload — redundant        | Low: cosmetic                            |
| OnlineStoreTemplateLive.Index | `:templates`                       | Form save: same redundant `stream_insert` + full reload              | Same                                                                             | Low                                      |
| ScrobbledTracksLive.Index     | `:tracks`                          | Form save, PubSub scrobble update                                    | Could incrementally `stream_insert` the edited track instead of full reload      | Medium: full FTS on every scrobble batch |
| RecordSetLive.Index           | `:record_sets`                     | Form create                                                          | Could `stream_insert` the new set without full reload                            | Low                                      |
| StatsLive.Index               | `:recent_tracks`, `:recent_albums` | PubSub scrobble update                                               | Incremental `stream_insert` could replace full reset                             | Medium: resets on every scrobble batch   |

### 4b. Synchronous Mount Work → Async Candidates

| LiveView             | Blocking queries                                                                                                                                     | Recommendation                                           | Impact                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ----------------------------- |
| StatsLive.Index      | `count_records_by_artist(20)`, `count_records_by_genre(20)`, `count_records_by_release_year(20)`, `get_records_on_this_day()`, `get_latest_record()` | Move to `assign_async` — these are below-the-fold charts | High: 5 queries blocking TTFB |
| CollectionLive.Index | `Chats.count_chats(:collection, ...)`                                                                                                                | Small, acceptable                                        | None                          |

### 4c. Server Round Trips → Client-Side Candidates

| Interaction                     | Current                                                                     | Optimizable?                                               | Impact                                       |
| ------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------- |
| Display mode toggle (grid↔list) | Server `handle_event("set_display")` → full DB query + stream reset         | Switch to client-side JS hook that toggles CSS class       | Medium: eliminates 1 round trip + 1 DB query |
| Search input                    | Every keystroke triggers `phx-change` → `handle_event("search")` → DB query | Check if `phx-debounce` is set. If not, add 300ms debounce | Medium: reduces query load                   |
| Sort order change               | `push_patch` → `handle_params` → DB query                                   | Cannot be client-side (pagination depends on sort order)   | N/A                                          |

### 4d. Optimistic UI Opportunities

| Operation                    | Current behavior                            | Optimistic approach                                                          | Risk                           |
| ---------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------ |
| Record delete                | `Repo.delete` → `stream_delete` (confirmed) | `stream_delete` immediately → `Repo.delete` in background; rollback on error | Low: delete failures are rare  |
| Form save in modal           | `push_patch` to base index → full reload    | `stream_insert` updated record into parent stream without navigation         | Medium: need to handle re-sort |
| Scrobble rule enabled toggle | Full list reload via `push_patch`           | Toggle `stream_insert` item in-place                                         | Low                            |
| Online store template toggle | Full list reload via `push_patch`           | Toggle `stream_insert` item in-place                                         | Low                            |

### 4e. N+1 and Query Pattern Audit

**Checklist**:

- [ ] `CollectionLive.Show.handle_params/3` — loads record, last_listened_track, play_count, record_sets, chat_count, embedding_text, similar_records. Check for N+1.
- [ ] `ArtistLive.Show.handle_params/3` — loads artist, collection_records, wishlist_records. Check for N+1.
- [ ] Stream rendering — check `.record_grid`, `.record_list`, `.record_card` components for per-item DB calls
- [ ] Verify preloads cover all rendered fields (artists, formats, genres, dominant_colors)

**Investigation method**:

1. Use QueryReporter skill to capture SQL for: `/collection`, `/collection/:id`, `/artists/:id`, `/stats`
2. Review stream usage with `grep -rn "stream(" lib/music_library_web/live/`
3. Check for `Repo` calls inside LiveComponents (should delegate to context)
4. Check for `Repo` calls inside `.heex` templates (should be in `handle_params`)

**Files to check**: All `lib/music_library_web/live/**/*.ex`, all `lib/music_library_web/components/*.ex`

<!-- SECTION:PLAN:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [ ] #1 Audit report for each phase written as a Backlog.md document with file paths, line references, severity ratings, and fix recommendations
- [ ] #2 At least one concrete finding identified per phase before considering the phase complete
- [ ] #3 Each finding includes a specific file:line reference (not just a general concern)
- [ ] #4 Findings are triaged by severity: HIGH (crashes/data loss), MEDIUM (wrong behavior/noticeable perf), LOW (cosmetic/redundant)
- [ ] #5 ML-168 is referenced where relevant but not duplicated — this audit identifies NEW issues only
- [ ] #6 No fixes implemented during audit — only identification and recommendation
<!-- DOD:END -->
