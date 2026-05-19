---
id: doc-26
title: "Audit Report: Concurrent State Change Safety (Phase 3)"
type: other
created_date: "2026-05-19 07:28"
tags:
  - audit
  - concurrency
  - worker
  - notify_update
  - race-condition
  - record
---

# Phase 3 Concurrent State Change Safety Audit

**Date:** 2026-05-19
**Scope:** All Oban workers that modify records matched against `Records.notify_update/1` broadcast coverage. Form-edit vs background-update race traced. Double-update race evaluated.

## Executive Summary

**Result: MINOR FINDING — one medium-severity race condition identified.** All 8 record-modifying workers correctly broadcast `notify_update` or `broadcast_index_changed`. Double-update between concurrent workers is safe due to Ecto changeset field-level updates + SQLite write serialization. However, the **form edit + background update race** (AC #3) can cause data loss: when a Show LiveView is in `:edit` mode and a worker broadcasts `{:update, record}`, the parent's `@record` assign is overwritten, and the user's next save can revert the worker's changes.

---

## Acceptance Criterion #1: Record-Modifying Worker Broadcast Coverage

**Status: ✅ ALL VERIFIED — every record-modifying worker broadcasts.**

### Workers that modify existing records (broadcast `notify_update`)

| Worker                         | File                                                           | Line | Fields modified                               | Broadcast call                          |
| ------------------------------ | -------------------------------------------------------------- | ---- | --------------------------------------------- | --------------------------------------- |
| `RefreshCover`                 | `lib/music_library/worker/refresh_cover.ex`                    | 14   | `cover_hash`                                  | `Records.notify_update(updated_record)` |
| `PopulateGenres`               | `lib/music_library/worker/populate_genres.ex`                  | 15   | `genres`                                      | `Records.notify_update(updated_record)` |
| `GenerateRecordEmbedding`      | `lib/music_library/worker/generate_record_embedding.ex`        | 16   | embedding (via Similarity, not record column) | `Records.notify_update(record)`         |
| `RecordRefreshMusicBrainzData` | `lib/music_library/worker/record_refresh_music_brainz_data.ex` | 14   | `musicbrainz_data`                            | `Records.notify_update(updated_record)` |

**Code verification:**

```elixir
# refresh_cover.ex:11-14
case Records.refresh_cover(record) do
  {:ok, updated_record} -> Records.notify_update(updated_record)  ✅
  {:error, :cover_not_available} -> {:cancel, :cover_not_available}
  other -> ErrorHandler.to_oban_result(other)
end

# populate_genres.ex:11-16
with {:ok, updated_record} <- Records.populate_genres(record),
     {:ok, _worker} <- Records.Similarity.generate_embedding_async(updated_record) do
  Records.notify_update(updated_record)  ✅
else
  other -> ErrorHandler.to_oban_result(other)
end

# generate_record_embedding.ex:14-16
case Similarity.generate_embedding(record) do
  :noop -> :ok
  {:ok, _} -> Records.notify_update(record)  ✅
  other -> ErrorHandler.to_oban_result(other)
end

# record_refresh_music_brainz_data.ex:12-15
case Records.refresh_musicbrainz_data(record) do
  {:ok, updated_record} -> Records.notify_update(updated_record)  ✅
  other -> ErrorHandler.to_oban_result(other)
end
```

### Workers that create new records (broadcast `broadcast_index_changed`)

| Worker                              | File                                                                | Line | Creates    | Broadcast call                         |
| ----------------------------------- | ------------------------------------------------------------------- | ---- | ---------- | -------------------------------------- |
| `ImportFromMusicbrainzRelease`      | `lib/music_library/worker/import_from_musicbrainz_release.ex`       | 24   | New record | `Records.broadcast_index_changed()` ✅ |
| `ImportFromMusicbrainzReleaseGroup` | `lib/music_library/worker/import_from_musicbrainz_release_group.ex` | 27   | New record | `Records.broadcast_index_changed()` ✅ |

These correctly use `broadcast_index_changed()` instead of `notify_update` because new records have no existing subscribers on `"records:#{id}"`.

### Batch workers (delegate to per-record async jobs)

| Worker                            | File                                                              | Delegates to                                                                                                                            | Individual worker broadcasts? |
| --------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `RecordGenerateAllEmbeddings`     | `lib/music_library/worker/record_generate_all_embeddings.ex`      | `Records.Batch.generate_embeddings()` → `Similarity.generate_embedding_async(record)` → enqueues `GenerateRecordEmbedding`              | ✅ Yes                        |
| `RecordRefreshAllMusicBrainzData` | `lib/music_library/worker/record_refresh_all_musicbrainz_data.ex` | `Records.Batch.refresh_musicbrainz_data()` → `Records.refresh_musicbrainz_data_async(record)` → enqueues `RecordRefreshMusicBrainzData` | ✅ Yes                        |

The batch workers (lines 8-10 of each file) don't call `notify_update` directly — they delegate to the individual workers which do. **Each individual record gets its own broadcast.** ✅

---

## Acceptance Criterion #2: Non-Record-Modifying Workers

**Status: ✅ ALL CONFIRMED — no spurious broadcasts.**

Grep for `notify_update` and `broadcast_index_changed` across `lib/music_library/worker/` returns exactly the 6 calls documented in AC #1. No other worker emits record PubSub messages.

| Worker                            | File                                                              | Modifies records?   | Broadcasts? |
| --------------------------------- | ----------------------------------------------------------------- | ------------------- | ----------- |
| `ApplyScrobbleRules`              | `lib/music_library/worker/apply_scrobble_rules.ex`                | No — tracks only    | ❌ No ✅    |
| `ArtistRefreshMusicBrainzData`    | `lib/music_library/worker/artist_refresh_music_brainz_data.ex`    | No — artist info    | ❌ No ✅    |
| `ArtistRefreshAllDiscogsData`     | `lib/music_library/worker/artist_refresh_all_discogs_data.ex`     | No — artist info    | ❌ No ✅    |
| `ArtistRefreshAllMusicBrainzData` | `lib/music_library/worker/artist_refresh_all_musicbrainz_data.ex` | No — artist info    | ❌ No ✅    |
| `ArtistRefreshAllWikipediaData`   | `lib/music_library/worker/artist_refresh_all_wikipedia_data.ex`   | No — artist info    | ❌ No ✅    |
| `ArtistRefreshDiscogsData`        | `lib/music_library/worker/artist_refresh_discogs_data.ex`         | No — artist info    | ❌ No ✅    |
| `ArtistRefreshWikipediaData`      | `lib/music_library/worker/artist_refresh_wikipedia_data.ex`       | No — artist info    | ❌ No ✅    |
| `BackfillScrobbledTracks`         | `lib/music_library/worker/backfill_scrobbled_tracks.ex`           | No — tracks only    | ❌ No ✅    |
| `FetchArtistImage`                | `lib/music_library/worker/fetch_artist_image.ex`                  | No — artist info    | ❌ No ✅    |
| `FetchArtistInfo`                 | `lib/music_library/worker/fetch_artist_info.ex`                   | No — artist info    | ❌ No ✅    |
| `FetchArtistLastFmData`           | `lib/music_library/worker/fetch_artist_last_fm_data.ex`           | No — artist info    | ❌ No ✅    |
| `PruneArtistInfo`                 | `lib/music_library/worker/prune_artist_info.ex`                   | No — cleanup        | ❌ No ✅    |
| `PruneAssetCache`                 | `lib/music_library/worker/prune_asset_cache.ex`                   | No — cleanup        | ❌ No ✅    |
| `PruneAssets`                     | `lib/music_library/worker/prune_assets.ex`                        | No — cleanup        | ❌ No ✅    |
| `RefreshScrobbles`                | `lib/music_library/worker/refresh_scrobbles.ex`                   | No — tracks only    | ❌ No ✅    |
| `RepoOptimize`                    | `lib/music_library/worker/repo_optimize.ex`                       | No — DB maintenance | ❌ No ✅    |
| `RepoVacuum`                      | `lib/music_library/worker/repo_vacuum.ex`                         | No — DB maintenance | ❌ No ✅    |
| `SendRecordsOnThisDayEmail`       | `lib/music_library/worker/send_records_on_this_day_email.ex`      | No — email          | ❌ No ✅    |

---

## Acceptance Criterion #3: Form Edit + Background Update Race

**Status: ⚠️ MEDIUM SEVERITY — potential data loss.**

### Race scenario trace

```
1. User opens RecordForm modal (live_action = :edit on CollectionLive.Show or WishlistLive.Show)
   RecordForm rendered with @record = {genres: [], cover_hash: "abc"}
   RecordForm's update/2 stores form via assign_new(:form, ...)

2. Background worker (e.g., PopulateGenres) completes
   Worker calls Records.notify_update(updated_record) with {genres: ["rock"], cover_hash: "abc"}

3. PubSub broadcasts {:update, record} on "records:#{record.id}"

4. Show LiveView's handle_info({:update, record}, socket) fires:
   └─ RecordActions.handle_record_updated(record)
      └─ assign(:record, record)          ← overwrites @record!
      └─ put_toast(:info, "Record updated in the background")  ← user sees toast

5. RecordForm's update/2 re-invoked with new @record
   assign(assigns)                         ← updates @record to worker version
   assign_new(:form, ...)                  ← skips: form already exists

6. User edits title and clicks Save
   handle_event("save", %{"record" => %{"title" => "New", "genres" => [], ...}})

7. save_record/3 calls:
   Records.update_record(socket.assigns.record, params)
   where params = %{"title" => "New", "genres" => [], "format" => "LP", ...}
   params.genres == [] ← stale! worker's genres: ["rock"] is LOST
```

### Root cause

The Show LiveView's `handle_info({:update, record})` does not check `live_action`:

```elixir
# collection_live/show.ex:474-483
def handle_info({:update, record}, socket) do
  if record.id == socket.assigns.record.id do          ← guards against wrong record
    {:noreply,
     socket
     |> RecordActions.handle_record_updated(record)     ← ALWAYS updates, even during :edit
     |> assign_similar_records()}
  else
    {:noreply, socket}
  end
end

# wishlist_live/show.ex:367-373 — identical pattern
```

When `live_action == :edit`, the updated `@record` propagates to the RecordForm component via `update/2`. While `assign_new(:form, ...)` preserves the user's form fields, the underlying `@record` is now stale relative to the form data. On save, the stale params overwrite the worker's changes.

### Impact assessment

| Factor              | Assessment                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Probability**     | LOW — workers are triggered by explicit user action, not periodic cron. User is unlikely to edit AND trigger a worker simultaneously. |
| **Impact**          | MEDIUM — worker changes silently reverted without error. User might not notice.                                                       |
| **Detectability**   | HIGH — toast "Record updated in the background" alerts user something changed.                                                        |
| **Affected fields** | `genres` (PopulateGenres), `musicbrainz_data` (RecordRefreshMusicBrainzData), `cover_hash` (RefreshCover)                             |

### Recommended fix

Add a `live_action` guard to skip `@record` assignment when the user is editing:

**File:** `lib/music_library_web/live/collection_live/show.ex:474-483`

```elixir
def handle_info({:update, record}, socket) do
  if record.id == socket.assigns.record.id do
    if socket.assigns.live_action in [:show] do
      {:noreply,
       socket
       |> RecordActions.handle_record_updated(record)
       |> assign_similar_records()}
    else
      # live_action == :edit: skip update to avoid overwriting form data.
      # The worker's changes are already persisted. When the user saves or
      # navigates back to show, handle_params will re-fetch the fresh record.
      {:noreply,
       put_toast(socket, :info, gettext("Record updated in the background. Your edits may be stale."))}
    end
  else
    {:noreply, socket}
  end
end
```

**Same change needed in:** `lib/music_library_web/live/wishlist_live/show.ex:367-373`

---

## Acceptance Criterion #4: Double-Update Race Between Concurrent Workers

**Status: ✅ SAFE — Ecto changeset field-level updates + SQLite serialization prevent data corruption.**

### Why it's safe

**1. Ecto changesets only UPDATE changed fields**

The enrichment functions construct changesets that touch only specific fields:

```elixir
# enrichment.ex:41-43 — PopulateGenres
record
|> Record.add_genres(response["genres"])    # changes: %{genres: [...]}
|> Repo.update()                            # UPDATE records SET genres = ... WHERE id = ...

# enrichment.ex:51-53 — RefreshCover
record
|> Record.set_cover_hash(asset.hash)        # changes: %{cover_hash: "xyz"}
|> Repo.update()                            # UPDATE records SET cover_hash = ... WHERE id = ...

# enrichment.ex:115-118 — RefreshMusicBrainzData
record
|> Record.add_musicbrainz_data(data)        # changes: %{musicbrainz_data: ...}
|> Repo.update()                            # UPDATE records SET musicbrainz_data = ... WHERE id = ...
```

Ecto's `Repo.update/1` with a changeset generates SQL that only includes columns in the changeset's `changes` map, **not** all cast fields. Two workers touching different columns produce non-overlapping UPDATEs.

**2. SQLite serializes writes**

SQLite uses a per-database write lock. Two concurrent writes are serialized (one waits for the other). The second write always sees the first write's committed state.

**3. Both broadcasts arrive**

Both workers broadcast `notify_update` after their respective commits. The Show LiveView processes both messages in order:

```
Worker A: commit → broadcast(record_A)
Worker B: commit → broadcast(record_B)

Show LV: handle_info(record_A) → assign record_A
Show LV: handle_info(record_B) → assign record_B   ← last wins, but DB has both changes
```

The final `socket.assigns.record` reflects the last broadcast (record_B), which was fetched by Worker B before Worker A committed. So the UI may momentarily lack Worker A's changes until the next full page load or PubSub refresh. This is a minor UI staleness issue, not data corruption.

**4. Verifying no full-struct UPDATE**

```elixir
# record.ex:134-152
def changeset(record, attrs) do
  record
  |> cast(attrs, [                               # cast: user-supplied params
      :type, :format, :title, :musicbrainz_id, :musicbrainz_data,
      :release_date, :genres, :release_ids, :selected_release_id,
      :included_release_group_ids, :cover_url, :cover_hash,
      :dominant_colors, :purchased_at
    ])
  ...
end
```

`cast/3` only puts fields present in `attrs` into `changes`. The enrichment functions use `change/2` (not `cast/3`) with explicit field lists, so only targeted fields end up in the UPDATE.

### Sequence diagram: Two workers, different fields

```
Worker A (PopulateGenres)              Worker B (RefreshCover)           SQLite DB
    │                                       │                              │
    │  get_record!(id) → v0                 │  get_record!(id) → v0        │  {genres:[], cover:"abc"}
    │  populate_genres(v0)                  │  download new cover          │
    │  add_genres(["rock"])                 │  set_cover_hash("xyz")       │
    │  Repo.update(chg: genres) ──────────── wait for lock ──────────────► │  {genres:["rock"], cover:"abc"}
    │                                       │  Repo.update(chg: cover) ──► │  {genres:["rock"], cover:"xyz"}
    │  notify_update(record_A)              │  notify_update(record_B)     │
    │  record_A: {genres:["rock"]}          │  record_B: {cover:"xyz"}     │
    │  (no cover_hash field)                │  (no genres field)           │
```

**Result:** DB has both changes. UI gets record_B (missing genres), but next `handle_params` reload corrects it. **No data loss.** ✅

---

## Acceptance Criterion #5: ArtistLive.Show and `{:update, record}`

**Status: ✅ CONFIRMED CORRECT — ArtistLive.Show intentionally does not handle `{:update, record}`.**

### Verification

**1. No PubSub subscription for record topics**

ArtistLive.Show's `mount/3` (line 498-500):

```elixir
def mount(_params, _session, socket) do
  {:ok, socket}
end
```

No `Records.subscribe/1` or `subscribe_to_index/0` call. The LiveView never receives `{:update, record}` messages. ✅

**2. handle_info clauses in ArtistLive.Show**

```elixir
# line 493, 639 — only two clauses:
def handle_info({MusicLibraryWeb.Components.Chat, :chats_changed}, socket)
def handle_info({MusicLibraryWeb.ArtistLive.Form, {:saved, artist_info}}, socket)
```

No `{:update, record}` clause. Any such message that somehow arrived would be silently dropped by Phoenix.LiveView (unmatched messages are ignored, not crashed). ✅

**3. Artist update path**

Artist updates use a distinct pub/sub path:

```
ArtistLive.Form (modal) → send(self(), {ArtistLive.Form, {:saved, artist_info}})
ArtistLive.Show → handle_info({:saved, artist_info}) → assign(:artist_info, ...)
```

Records displayed in ArtistLive.Show's grids are refreshed via `assign_records/2` (which re-queries the DB) when the user triggers an action like `add-to-collection` or `delete`. No push-based record update. ✅

---

## Complete Worker Broadcast Matrix

| #   | Worker                              | File:Line                                     | Broadcast                   | Fields Touched                | Severity |
| --- | ----------------------------------- | --------------------------------------------- | --------------------------- | ----------------------------- | -------- |
| 1   | `RefreshCover`                      | `refresh_cover.ex:14`                         | `notify_update(updated)`    | `cover_hash`                  | ✅ OK    |
| 2   | `PopulateGenres`                    | `populate_genres.ex:15`                       | `notify_update(updated)`    | `genres`                      | ✅ OK    |
| 3   | `GenerateRecordEmbedding`           | `generate_record_embedding.ex:16`             | `notify_update(record)`     | embedding (not record column) | ✅ OK    |
| 4   | `RecordRefreshMusicBrainzData`      | `record_refresh_music_brainz_data.ex:14`      | `notify_update(updated)`    | `musicbrainz_data`            | ✅ OK    |
| 5   | `ImportFromMusicbrainzRelease`      | `import_from_musicbrainz_release.ex:24`       | `broadcast_index_changed()` | new record insert             | ✅ OK    |
| 6   | `ImportFromMusicbrainzReleaseGroup` | `import_from_musicbrainz_release_group.ex:27` | `broadcast_index_changed()` | new record insert             | ✅ OK    |
| 7   | `RecordGenerateAllEmbeddings`       | (delegates to GenerateRecordEmbedding)        | per-record `notify_update`  | embedding                     | ✅ OK    |
| 8   | `RecordRefreshAllMusicBrainzData`   | (delegates to RecordRefreshMusicBrainzData)   | per-record `notify_update`  | `musicbrainz_data`            | ✅ OK    |

All 8 record-modifying workers verified. ✅

---

## Recommendations

| #   | Finding                                                                                                                                        | Severity   | Recommendation                                                                                                                                                                                                                                                                                                        |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Form edit + background update race — `handle_info({:update, record})` overwrites `@record` during `:edit`, causing potential data loss on save | **MEDIUM** | Add `live_action == :show` guard to `handle_info({:update, record})` in both `CollectionLive.Show` (line 474) and `WishlistLive.Show` (line 367). Skip `assign(:record, ...)` during `:edit`. Show warning toast instead. The fresh record will be loaded on next `handle_params` when user navigates away from edit. |
| 2   | Double-update broadcasts cause brief UI staleness                                                                                              | ℹ️ INFO    | Harmless — last broadcast wins on socket, but DB has all changes. Next `handle_params` reload fetches everything. No fix needed.                                                                                                                                                                                      |
| 3   | Batch workers (`RecordGenerateAllEmbeddings`, `RecordRefreshAllMusicBrainzData`) don't call `notify_update` directly                           | ℹ️ INFO    | By design — they delegate to individual workers which broadcast per record. No fix needed.                                                                                                                                                                                                                            |
