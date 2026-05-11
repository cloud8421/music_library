---
id: ML-170
title: Expose additional data points for api/v1/collection/* records
status: To Do
assignee: []
created_date: "2026-05-08 13:02"
updated_date: "2026-05-11 06:46"
labels:
  - api
dependencies: []
documentation:
  - doc-14 - Research-Exposing-additional-data-points-for-collection-API.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The current `/api/v1/collection/*` API endpoints return a subset of record fields from the SearchIndex virtual table. The following additional data points should be exposed to API consumers:

1. **Scrobble count** (if available) — number of times tracks from this record have been listened to (from Last.fm scrobble data in the `scrobbled_tracks` table)
2. **Last listened at date** — timestamp of the most recent scrobble for this record
3. **Collected release information** — details about specific releases (editions) that are part of the collection for each record/release group
4. **Artist country** — the country/area of the main artist, available via `MusicLibrary.Artists.ArtistInfo`

Currently, `CollectionJSON` maps SearchIndex fields into a flat JSON record with: id, type, format, musicbrainz_id, genres, release_date, purchased_at, artists (names only), title, and cover_url variants. None of the above data points are exposed.

The API endpoints affected are:

- `GET /api/v1/collection` (index, paginated)
- `GET /api/v1/collection/latest`
- `GET /api/v1/collection/random`
- `GET /api/v1/collection/on_this_day`
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 `GET /api/v1/collection` (index) responses include `scrobble_count`, `last_listened_at`, `artist_country`, and `selected_release` for each record
- [ ] #2 `GET /api/v1/collection/latest` response includes all four new fields
- [ ] #3 `GET /api/v1/collection/random` response includes all four new fields
- [ ] #4 `GET /api/v1/collection/on_this_day` responses include all four new fields for each record
- [ ] #5 Records without scrobble data return `scrobble_count: 0` and `last_listened_at: null`
- [ ] #6 Records without artist info return `artist_country: null`
- [ ] #7 Records without a selected release return `selected_release: null`
- [ ] #8 All existing tests pass (backward compatible — no existing field removed or renamed)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### Overview

Add a `MusicLibrary.Collection.Enrichment` module that batch-hydrates SearchIndex (and Record struct) results with three new data dimensions (scrobble stats, artist country, selected release info) using fixed-count batch SQL queries. The enrichment layer runs in the controller after the initial query, before JSON rendering.

### Architecture impact analysis

| Touchpoint                                                   | Impact                                                                                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `lib/music_library/collection.ex`                            | New sub-module `MusicLibrary.Collection.Enrichment`                                                                            |
| `lib/music_library_web/controllers/collection_json.ex`       | Extended `record/1` to include new fields with nil-safe `Map.get/3`                                                            |
| `lib/music_library_web/controllers/collection_controller.ex` | Wire enrichment call between query and render in all 4 actions                                                                 |
| Schemas (`SearchIndex`, `Record`)                            | **No changes** — enrichment works on maps/structs with `id`, `release_ids`, `selected_release_id`, and `artists` embedded list |
| Database                                                     | **No migrations** — reads existing `scrobbled_tracks`, `records`, `artist_infos`, `record_releases`                            |
| Routes                                                       | No changes                                                                                                                     |
| PubSub                                                       | No changes                                                                                                                     |
| Supervision tree                                             | No changes                                                                                                                     |
| External APIs                                                | No changes                                                                                                                     |

**Data source compatibility:** The 4 controller actions use different query paths. Verify each path produces results with the fields enrichment needs:

| Action        | Query path                        | Result type          | Has `release_ids`?        | Has `artists`?    | Has `selected_release_id`? |
| ------------- | --------------------------------- | -------------------- | ------------------------- | ----------------- | -------------------------- |
| `index`       | `SearchIndex` via FTS5            | `SearchIndex` struct | ✅ yes (array of strings) | ✅ yes (embedded) | ✅ yes (string)            |
| `latest`      | `Record` via `essential_fields()` | Record struct / map  | ✅ yes                    | ✅ yes            | ✅ yes                     |
| `random`      | same as `latest`                  | same                 | ✅ yes                    | ✅ yes            | ✅ yes                     |
| `on_this_day` | `Record` via `essential_fields()` | Record struct / map  | ✅ yes                    | ✅ yes            | ✅ yes                     |

All paths produce results with the three required fields. Enrichment functions accept any map with those keys.

### Scope clarification

"Collected release information" means the **single selected release** per record (`selected_release_id` → details from `musicbrainz_data`), not the full list of all releases. The field is named `selected_release` in the API response.

---

### Step 1: Create `MusicLibrary.Collection.Enrichment` module

Create `lib/music_library/collection/enrichment.ex` with three public functions and a composition function:

```elixir
@spec enrich([map()]) :: [map()]
def enrich(records)

@spec enrich_scrobbles([map()]) :: [map()]
def enrich_scrobbles(records)

@spec enrich_artist_country([map()]) :: [map()]
def enrich_artist_country(records)

@spec enrich_selected_release([map()]) :: [map()]
def enrich_selected_release(records)
```

**Data flow:**

```
maps[] → enrich_scrobbles() → enrich_artist_country() → enrich_selected_release() → maps[]
```

Each function is independently callable and testable. `enrich/1` composes all three via pipeline.

**Verification:** Unit tests for each enrichment function verify correct field additions.

---

### Step 2: Implement `enrich_scrobbles/1`

**Algorithm:**

1. Collect all `release_ids` from all records into a flat, unique, non-empty list.
2. **Guard:** If the collected list is empty (all records have `release_ids: []` or `nil`), return records unchanged with `scrobble_count: 0, last_listened_at: nil` on each.
3. Single batch query against `scrobbled_tracks`:

```sql
SELECT json_extract(album, '$.musicbrainz_id') AS release_id,
       COUNT(DISTINCT scrobbled_at_uts) AS scrobble_count,
       MAX(scrobbled_at_uts) AS last_listened_at
FROM scrobbled_tracks
WHERE json_extract(album, '$.musicbrainz_id') IN (?)
GROUP BY 1
```

4. Build a lookup map `%{release_id => %{scrobble_count, last_listened_at}}`.
5. For each record, sum scrobble counts across its `release_ids` (a release group may have multiple releases, each with scrobbles) and take the `MAX` of `last_listened_at`.
6. For records with no matching release IDs in the lookup, `scrobble_count: 0, last_listened_at: nil`.

**No title+artist fallback.** The batch release_id lookup is sufficient. Records without scrobbles correctly show zero/null. If a stakeholder later requires title+artist matching, that is a separate follow-up with its own performance analysis — it would add N individual queries and break the fixed-query-count guarantee.

**Uses existing index:** `scrobbled_tracks_album_musicbrainz_id_index` on `json_extract(album, '$.musicbrainz_id')`.

**Converts `last_listened_at` to ISO8601 string** after the query (UNIX timestamp → `DateTime.from_unix!` → `DateTime.to_iso8601`).

**Edge case — shared release_ids across records:** Two records may share the same release group (different formats). This is correctly handled: the lookup map is per release_id, and each record independently sums across its own `release_ids`.

**Verification:**

- Records with scrobble matches → `scrobble_count > 0`, `last_listened_at` is a non-nil ISO8601 string
- Records with no scrobbles → `scrobble_count: 0`, `last_listened_at: nil`
- Records with empty/nil `release_ids` → `scrobble_count: 0`, `last_listened_at: nil`
- Two records sharing a release group → both correctly attribute scrobbles
- Verify `last_listened_at` is the most recent timestamp across all releases in the group

---

### Step 3: Implement `enrich_artist_country/1`

**Algorithm:**

1. Extract main artist `musicbrainz_id` from each record's `artists` embedded list (first element only — `hd(record.artists)`).
2. Collect unique non-nil artist IDs.
3. **Guard:** If no artist IDs, return records unchanged with `artist_country: nil`.
4. Batch query `artist_infos` (primary key lookup — uses existing PK index):

```sql
SELECT id, musicbrainz_data
FROM artist_infos
WHERE id IN (?)
```

5. For each row, extract country using `MusicLibrary.Artists.ArtistInfo.country/1` (parses `musicbrainz_data.area.iso-3166-1-codes`, falls back to `musicbrainz_data.country`, returns `%{name: "World", code: "XW"}` if no area data).
6. Build lookup map `%{artist_mbid => %{name: country_name, code: country_code}}`.
7. Add `artist_country` (map, or nil if no `artist_infos` row exists for that artist).

**Performance note:** `artist_infos.musicbrainz_data` is a full MusicBrainz JSON blob. Loading it for up to 20 unique artists per page is acceptable. The JSON extraction (`ArtistInfo.country/1`) is in Elixir, not SQL — correct, as the extraction logic (iso-3166-1-codes vs iso-3166-2-codes vs country fallback) is non-trivial.

**Verification:**

- Artist with country data → `artist_country: %{name: "...", code: "..."}`
- Artist with no `artist_infos` row → `artist_country: nil`
- Record with empty artists list → `artist_country: nil`
- Multiple records with same main artist → reuse single lookup entry (dedup works)

---

### Step 4: Implement `enrich_selected_release/1`

**Algorithm:**

1. Collect record IDs where `selected_release_id` is not nil and not empty string.
2. **Guard:** If no record IDs qualify, return records unchanged with `selected_release: nil`.
3. Batch query `records` (primary key lookup — uses existing PK index):

```sql
SELECT id, musicbrainz_data, selected_release_id
FROM records
WHERE id IN (?)
```

4. For each record, extract the selected release from `musicbrainz_data` using `Record.releases/1` + `Record.find_release/2`.
5. Fields to expose from the selected release:
   - `format` — parsed from media formats (e.g., "cd", "vinyl", "multi")
   - `date` — release date string
   - `country` — country code (e.g., "US", "GB", "XW")
   - `catalog_number` — catalog number string
   - `packaging` — packaging description
   - `disambiguation` — disambiguation comment
6. Add `selected_release` (map or nil) to each record.

**Performance note:** `records.musicbrainz_data` is a large JSON blob (full release group with releases, tracks, media). Loading it for up to 20 records per page is acceptable. The plan does not attempt to extract the selected release in SQL — this is correct, as `Record.releases/1` and `Record.find_release/2` contain release ordering logic (by date, country) that would be impractical to replicate in SQL.

**Verification:**

- Record with valid `selected_release_id` that exists in `musicbrainz_data` → all 6 fields populated
- Record with `selected_release_id` that doesn't match any release in `musicbrainz_data` → `selected_release: nil`
- Record with nil/empty `selected_release_id` → `selected_release: nil`
- Record not in the batch query (not in DB) → `selected_release: nil`

---

### Step 5: Update `CollectionJSON`

Extend the `record/1` function to include new fields using `Map.get/3` with safe defaults:

```elixir
defp record(record) do
  %{
    # ... existing fields unchanged ...
    scrobble_count: Map.get(record, :scrobble_count, 0),
    last_listened_at: Map.get(record, :last_listened_at),
    artist_country: Map.get(record, :artist_country),
    selected_release: Map.get(record, :selected_release)
  }
end
```

Using `Map.get/3` ensures backward compatibility: the function works with both raw SearchIndex structs (no enrichment) and enriched maps. No existing fields are removed or renamed.

**Verification:** Controller tests validate the new JSON shape.

---

### Step 6: Update `CollectionController`

Wire enrichment into all four actions. The pattern is:

```elixir
records = Collection.search_records(...)
enriched = Collection.Enrichment.enrich(records)
render(conn, :index, records: enriched, total: total, ...)
```

**Affected actions:**

- `index` — enrich paginated results before render
- `latest` — enrich single record before render (wrap in list, enrich, unwrap)
- `random` — enrich single record before render (same pattern)
- `on_this_day` — enrich results list before render

**Verification:** Integration tests for each endpoint confirm new fields in response.

---

### Step 7: Write tests

**Unit tests** (`test/music_library/collection/enrichment_test.exs`):

- `enrich_scrobbles/1` — with matches, without matches, empty release_ids, shared release_ids
- `enrich_artist_country/1` — with country, without artist_info, without artists
- `enrich_selected_release/1` — with selected release, without selected_release_id, with non-matching release_id
- `enrich/1` — composition of all three, verifying fields accumulate correctly

**Controller tests** (update `test/music_library_web/controllers/collection_controller_test.exs`):

- Update `expected_record_json/1` to include new fields with expected shapes
- Test nil/null values for records without enrichment data
- Test all 4 endpoints (`index`, `latest`, `random`, `on_this_day`) include the new fields

**End-to-end test** — verify the exact API response JSON shape for each of the 4 endpoints with records that have enrichment data (requires fixture setup with scrobbled_tracks, artist_infos, and records with musicbrainz_data).

**Verification:** `mix test test/music_library/collection/enrichment_test.exs test/music_library_web/controllers/collection_controller_test.exs`

---

### Performance profile

| Operation                 | Query count                               | Complexity                                                     |
| ------------------------- | ----------------------------------------- | -------------------------------------------------------------- |
| `enrich_scrobbles`        | 1 batch query                             | O(R + T) where R=records per page, T=matching scrobbled_tracks |
| `enrich_artist_country`   | 1 batch query                             | O(A) where A=unique artists per page                           |
| `enrich_selected_release` | 1 batch query + in-memory JSON extraction | O(R)                                                           |
| **Total per request**     | **exactly 3 queries**                     | All fixed-cost regardless of total table size                  |

No N+1 risk — all batch queries scale with page size (≤20 records), not table size. No title+artist fallback queries.

**Memory:** All enrichment data fits in maps proportional to page size. `musicbrainz_data` JSON blobs are loaded for up to 20 records and 20 artists, then discarded after field extraction. At typical MusicBrainz payload sizes (~50-200KB per release group), worst-case memory is under 10MB per request.

**Indexes used:**

- `scrobbled_tracks_album_musicbrainz_id_index` for scrobble batch query (index seek, not table scan)
- `artist_infos` primary key for artist country lookup
- `records` primary key for selected release lookup

No new indexes needed.

---

### Production Changes

None required. This is a read-only change that adds fields to existing API responses. No migrations, no environment variables, no service provisioning.

**Rollback:** Remove the enrichment call from controllers (one line per action). The `CollectionJSON.record/1` function gracefully handles missing enrichment fields via `Map.get/3` defaults.

### Documentation updates

- **`docs/architecture.md`**: Add `MusicLibrary.Collection.Enrichment` to the Contexts + Modules section under `MusicLibrary.Collection`. Note that collection API responses include scrobble stats, artist country, and selected release data.
- **API response documentation**: If any README or doc page describes the `/api/v1/collection` response shape, update it to document the four new fields:
  - `scrobble_count` (integer, always present, defaults to 0)
  - `last_listened_at` (ISO8601 string or null)
  - `artist_country` (`{name: String, code: String}` or null — country of the main artist)
  - `selected_release` (`{format, date, country, catalog_number, packaging, disambiguation}` or null)
- **No changes** to `docs/project-conventions.md`, `docs/production-infrastructure.md`, or README needed.
<!-- SECTION:PLAN:END -->
