---
id: doc-27
title: "Phase 4 Performance Audit: Low-Hanging Fruit Findings"
type: specification
created_date: "2026-05-19 07:44"
tags:
  - audit
  - performance
  - findings
---

# Phase 4 Performance Audit: Low-Hanging Fruit Findings

**Date**: 2026-05-19
**Parent Task**: ML-169 (Comprehensive Application Audit)
**Query Trace**: `/tmp/queries-ml-audit.sql`

## Summary

Audited all LiveView pages for unnecessary DB queries, redundant stream reloads,
server round-trips that could be client-side, missing optimistic UI, and blocking
mount work. **9 findings** across 4 severity levels.

---

## Finding 1: Display toggle (grid/list) triggers full DB reload **[HIGH]**

**Files**: `lib/music_library_web/live_helpers/index_actions.ex:136-143`,
`lib/music_library_web/live/collection_live/index.ex:336`,
`lib/music_library_web/live/wishlist_live/index.ex:259`

**Problem**: `handle_set_display` calls `load_and_assign_records/2` which
re-executes the full FTS search query (`search_records_count` + `search_records`)
when the user toggles between grid and list views. The toggle only changes the
CSS layout class (`@display == :grid` vs `@display == :list`). No data changes.

**Severity**: HIGH — every display toggle wastes 2 FTS queries.

**Fix**: Remove `load_and_assign_records` call from `handle_set_display`.
Only `assign(:display, mode)` is needed. The existing `:if={@display == :grid}`
conditionals already handle showing/hiding the appropriate view.

```diff
def handle_set_display(socket, mode) do
    mode = parse_mode(mode)
    {:noreply,
     socket
     |> assign(:display, mode)}
-     |> load_and_assign_records(socket.assigns.record_list_params)}
end
```

---

## Finding 2: StatsLive.Index mount has 10 synchronous queries blocking TTFB **[HIGH]**

**File**: `lib/music_library_web/live/stats_live/index.ex:67-109`

**Problem**: The mount callback executes 10 synchronous Ecto queries before
returning `{:ok, socket}`. This blocks the initial render (TTFB).

Queries executed (confirmed via QueryReporter):

1. `Collection.get_latest_record()` — ORDER BY purchased_at LIMIT 1
2. `Collection.count_records_by_artist(limit: 20)` — json_each + GROUP BY
3. `Collection.count_records_by_genre(limit: 20)` — json_each + GROUP BY + subquery exclusion
4. `Collection.count_records_by_release_year(limit: 20)` — substr + GROUP BY
5. `Collection.get_records_on_this_day(date)` — strftime + ORDER BY
6. `Collection.count_records_by_format()` — GROUP BY format
7. `Collection.count_records_by_type()` — GROUP BY type
8. `Wishlist.count()` — FTS search count
9. `ListeningStats.recent_activity(timezone)` — 4 correlated subqueries × 100 rows
10. `ListeningStats.scrobble_count()` — simple COUNT

**Severity**: HIGH — 10 blocking queries on the home page. The `assign_async`
pattern is already in use for TopAlbums/TopArtists on the same page — apply it
consistently.

**Fix**: Use `assign_async` to defer non-critical queries. The critical ones
(collection_count, wishlist_count, scrobble_count for the counters) can stay
sync since they're fast. Move the heavy ones (count_records_by_artist/genre/release_year,
get_records_on_this_day, recent_activity) to `assign_async`.

---

## Finding 3: Stream reset on every scrobble PubSub update **[HIGH]**

**Files**:

- `lib/music_library_web/live/stats_live/index.ex:576-583` (`assign_scrobble_activity`)
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex:279` (`handle_info(%{track_count: _count})`)
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex:334` (`load_and_assign_tracks`)

**Problem**: Every scrobble batch (cron: every 5 minutes) triggers a
`"listening_stats:update"` PubSub message which causes both StatsLive.Index
and ScrobbledTracksLive.Index to reload their entire stream with `reset: true`.
StatsLive re-executes `recent_activity` (the expensive 4-correlated-subquery
query) + `scrobble_count`. ScrobbledTracksLive re-executes the full paginated
list query.

**Severity**: HIGH — fires every 5 minutes on all connected clients, even
those who haven't interacted with the page.

**Fix**:

- For StatsLive: Use `stream_insert` for new tracks instead of `reset: true`
- For ScrobbledTracksLive: Use `stream_insert` for new tracks only if they
  match the current search/filter; otherwise show a "new scrobbles" badge
  that refreshes on user click
- Consider a "last seen" cursor to only insert genuinely new tracks

---

## Finding 4: Redundant stream_insert + immediate full reload **[MEDIUM]**

**Files**:

- `lib/music_library_web/live/scrobble_rules_live/index.ex:247-253` (`handle_info({Form, {:created, ...})`)
- `lib/music_library_web/live/online_store_template_live/index.ex:195-201` (`handle_info({Form, {:saved, ...})`)

**Problem**: After a create/save operation, the code performs a correct
`stream_insert` (incremental insert) but then immediately calls
`load_and_assign_*/2` which does a full `stream(..., reset: true)` —
completely negating the benefit of `stream_insert`.

The same pattern exists for delete operations in both LiveViews.

**Severity**: MEDIUM — wastes a database query after every create/save/delete.

**Fix**: Remove the `load_and_assign_*` call after `stream_insert`. The stream
already has the correct data. For delete, `stream_delete` already removes the
item from the stream — no full reload needed.

---

## Finding 5: Full stream resets on every search/pagination/order change **[MEDIUM]**

**Files**:

- `lib/music_library_web/live_helpers/index_actions.ex:89` (`load_and_assign_records`)
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex:334` (`load_and_assign_tracks`)
- `lib/music_library_web/live/artist_live/show.ex:698-699` (`assign_records`)

**Problem**: Every search query change, order toggle, or pagination click
triggers a full `stream(..., reset: true)`. While `reset: true` is the
correct behavior when the entire dataset changes (new search query), it's
unnecessary for pagination within the same search.

**Severity**: MEDIUM for pagination (could append/prepend), LOW for search/order
changes (data genuinely changes).

**Fix for pagination**: Use `stream(..., at: -1)` (append) for "load more"
patterns, or `reset: true` only when search/order changes, not on page change.

---

## Finding 6: Missing optimistic UI for delete operations **[MEDIUM]**

**Files**:

- `lib/music_library_web/live_helpers/index_actions.ex:94-98` (`handle_delete`)
- `lib/music_library_web/live/collection_live/show.ex:381-385` (`handle_event("delete")`)
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex:305-310` (`handle_event("delete")`)

**Problem**: All delete operations wait for the database transaction to complete
before updating the UI. `stream_delete` is already used in some places, but the
pattern is inconsistent. CollectionLive.Show deletes don't use `stream_delete`
at all (they navigate away).

**Severity**: MEDIUM — adds latency to delete operations that could feel instant.

**Fix**: Use `stream_delete` immediately, then perform the DB operation async.
If DB fails, re-insert the item and show error toast.

```elixir
def handle_delete(socket, id) do
  record = Records.get_record!(id)
  socket = stream_delete(socket, :records, record)

  Task.start(fn -> Records.delete_record(record) end)

  {:noreply, socket}
end
```

---

## Finding 7: Correlated subqueries in ListeningStats.recent_activity **[MEDIUM]**

**File**: `lib/music_library/listening_stats.ex:339-397` (`tracks_with_record_info_query`)

**Problem**: The `tracks_with_record_info_query` includes 3 correlated subqueries
per row (matching_records, artist_id, cover_hash), each with a nested subquery
through `record_releases`. This runs for up to 100 tracks on every StatsLive
mount and every scrobble update.

SQL captured:

```sql
SELECT ...,
  (SELECT json_group_array(...) FROM records r
   WHERE r.musicbrainz_id = (
     SELECT r2.musicbrainz_id FROM records r2
     INNER JOIN record_releases rr ON rr.record_id = r2.id
     WHERE rr.release_id = (album ->> '$.musicbrainz_id') LIMIT 1
   )),
  (SELECT min(ar.musicbrainz_id) FROM artist_records ar ...),
  (SELECT r.cover_hash FROM records r ...)
FROM scrobbled_tracks ORDER BY scrobbled_at_uts DESC LIMIT 100;
```

**Severity**: MEDIUM — the 3 correlated subqueries per row (300 total for 100 tracks)
have significant overhead on each refresh. Already mitigated by the comment
"cost scales with number of result rows (≤ limit)" but still notable.

**Fix**: Consider a batch post-processing approach: fetch tracks, collect all
unique album release IDs, batch-look up records in a single query, then merge
in Elixir.

---

## Finding 8: Search input debounce — all verified **[PASS]**

**Files checked**:

- `lib/music_library_web/components/core_components.ex:75` — `phx-debounce="500"` (shared `search_form`)
- `lib/music_library_web/components/add_record.ex:48` — `phx-debounce="500"`
- `lib/music_library_web/components/scrobble_rule_picker.ex:43` — `phx-debounce="500"`
- `lib/music_library_web/live/universal_search_live/index.ex:30` — `phx-debounce="300"`
- `lib/music_library_web/live/record_set_live/record_picker.ex:37` — `phx-debounce="500"`

**Result**: All search inputs have `phx-debounce` set. ✓ No action needed.

---

## Finding 9: N+1 audit — no direct N+1 issues found **[PASS]**

**Files audited**: All LiveViews and LiveComponents under `lib/music_library_web/`

**Result**: No direct `Repo` calls found in LiveView/LiveComponent files. All
data access goes through context modules which use paginated queries with
limit/offset. The `assign_async` pattern is correctly used for expensive
operations (TopByPeriod, ArtistLive similar_artists, Release component).

**Note**: The `ListeningStats.recent_activity` correlated subqueries (Finding 7)
are a related performance concern but not a classic N+1.

---

## Severity Summary

| Finding                             | Severity | Impact                                      |
| ----------------------------------- | -------- | ------------------------------------------- |
| #1 Display toggle FTS reload        | HIGH     | Every grid/list toggle wastes 2 FTS queries |
| #2 StatsLive 10 sync queries        | HIGH     | Home page TTFB blocked by 10 queries        |
| #3 Scrobble reset on every batch    | HIGH     | Fires every 5 min on all clients            |
| #4 Redundant insert+reload          | MEDIUM   | Wasted queries on create/save/delete        |
| #5 Full resets on search/pagination | MEDIUM   | Excessive for pagination within same search |
| #6 Missing optimistic UI            | MEDIUM   | Delete/form latency                         |
| #7 Correlated subqueries            | MEDIUM   | 300 subqueries per recent_activity call     |
| #8 Search debounce                  | PASS     | All inputs have debounce ✓                  |
| #9 N+1 audit                        | PASS     | No N+1 issues found ✓                       |
