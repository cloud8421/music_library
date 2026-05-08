---
id: doc-14
title: "Research: Exposing additional data points for collection API"
type: specification
created_date: "2026-05-08 13:03"
updated_date: "2026-05-08 14:01"
tags:
  - api
  - collection
  - research
---

# Research: Exposing additional data points for collection API

## Problem

The `/api/v1/collection/*` endpoints currently return a flat subset of SearchIndex fields. We need to add four new data points per record:

| Data Point             | Source                                        | Current Access Pattern                           | Cost                                        |
| ---------------------- | --------------------------------------------- | ------------------------------------------------ | ------------------------------------------- |
| Scrobble count         | `scrobbled_tracks`                            | `ListeningStats.play_count/1`                    | 2 queries per record                        |
| Last listened at       | `scrobbled_tracks`                            | `ListeningStats.get_last_listened_track/1`       | 2 queries per record                        |
| Collected release info | `records.musicbrainz_data`, `record_releases` | `Record.releases/1`, `Record.selected_release/1` | Requires Record struct (not in SearchIndex) |
| Artist country         | `artist_infos.musicbrainz_data`               | `ArtistInfo.country/1`                           | 1 query per artist                          |

## Current architecture

- Collection API queries `records_search_index` (FTS5 virtual table), populated by triggers from `records`
- `SearchIndex` has a subset of Record columns; no `musicbrainz_data`, `artist_infos`, or scrobble data
- The JSON view (`CollectionJSON`) maps SearchIndex structs directly

## Implementation routes

### Route A: Post-query hydration layer (recommended)

Add a new enrichment module in `MusicLibrary.Collection` that batch-fetches additional data after the initial SearchIndex query.

**How it works:**

1. Execute existing SearchIndex query as before
2. Pass results through `Collection.enrich/1` which:
   a. Collects all record IDs → batch-queries `records` table for `release_ids` and main artist MBIDs
   b. Collects all release IDs → batch-queries `scrobbled_tracks` for play counts and most recent scrobble per release group
   c. Collects unique artist MBIDs → batch-queries `artist_infos` for country data
   d. Optionally queries `record_releases` for collected edition details
3. Merge enriched data into the JSON response map

**Changes required:**

- New functions: `Collection.enrich_scrobble_stats/1`, `Collection.enrich_artist_country/1`, `Collection.enrich_release_details/1`
- Update `CollectionJSON.record/1` to accept enriched data
- Update `CollectionController` actions to call enrichment
- New tests: enriched response shape, batch query correctness, nil handling for records without scrobbles/artist info

**Pros:**

- No migrations or SearchIndex trigger changes
- Clean separation of concerns — enrichment is opt-in and independently testable
- Can add `?include=scrobbles,country,releases` query params later for selective enrichment
- Existing API shape unchanged for clients not reading new fields

**Cons:**

- Additional queries (but batchable: ~3-5 queries total regardless of result count)
- Slightly slower response for the index endpoint (est. 5-20ms added for 20 records with SQLite)

**Performance profile:**

- Batch scrobble lookup: 1 query with `WHERE album_mbid IN (...release_ids...)` across all records in the page (constant query count, scales with page size not total table size)
- Batch artist_info lookup: 1 query with `WHERE id IN (...artist_mbids...)`
- Batch record_releases lookup: 1 query with `WHERE record_id IN (...record_ids...)`
- Total: ~3 additional queries for index endpoint (20 records), ~2 for single-record endpoints
- Memory: minimal — aggregated counts/dates, not loading full tables

### Route B: Add columns to SearchIndex + triggers

Extend the FTS5 virtual table and its sync triggers to include the new data points directly.

**How it works:**

1. Migration: add `scrobble_count INTEGER`, `last_listened_at INTEGER`, `artist_country TEXT`, `release_details TEXT` to SearchIndex
2. Update triggers to compute or join these values when records change
3. Scrobble data would need separate triggers on `scrobbled_tracks` to update SearchIndex

**Changes required:**

- Migration with `ALTER VIRTUAL TABLE` (FTS5 has limitations)
- New triggers on `records` for artist country, release details
- New triggers on `scrobbled_tracks` for scrobble counts and last listened at
- Update `essential_fields()` to include new columns
- Update `CollectionJSON` to map new fields

**Pros:**

- Zero additional queries per API request
- Consistent with existing SearchIndex-first architecture

**Cons:**

- FTS5 virtual tables are complex to alter; may require full rebuild
- Triggers on `scrobbled_tracks` fire on every scrobble import (high write volume), keeping SearchIndex in sync adds write overhead
- Data staleness: scrobble counts change frequently; SearchIndex would lag behind (or be constantly rebuilt)
- Tight coupling: SearchIndex purpose is search, not analytics
- Artist country requires joining `artist_records` → `artist_infos` in a trigger, which is fragile

### Route C: Separate details endpoint

Keep index endpoints lightweight and add a new `GET /api/v1/collection/:id` endpoint for enriched single-record views.

**How it works:**

1. Index endpoints remain unchanged
2. New show endpoint fetches a record + all enrichment data
3. Can use `ListeningStats.play_count/1` and `get_last_listened_track/1` directly since it's a single record

**Changes required:**

- New route and controller action
- New JSON view for enriched record
- Tests for new endpoint

**Pros:**

- Zero impact on existing index endpoint performance
- Per-record functions (`play_count/1`, `get_last_listened_track/1`) work for single records without batching
- Clean API design: lightweight list, heavy detail

**Cons:**

- Clients need two API calls to get enriched data for multiple records
- Doesn't satisfy the requirement if the user wants enriched data in index responses

## Recommendation

**Route A (post-query hydration)** is the recommended approach because:

1. It satisfies the requirement of adding data to existing endpoints without architectural changes
2. Performance impact is minimal (~3 batch queries regardless of page size)
3. No migration or trigger complexity
4. Can be implemented incrementally (scrobble stats first, then country, then releases)
5. Easily extended to support `?include=` query parameters for selective enrichment in the future

Routes B and C have merit but introduce either significant complexity (B) or don't fully satisfy the requirement (C).

## Open questions for decision

1. **"Collected release information" — what specifically?** Options include:
   - Just the `selected_release_id` (already in SearchIndex — trivial)
   - List of `release_ids` with their formats/types from `record_releases`
   - Full MusicBrainz release data (tracks, dates, countries) from `records.musicbrainz_data`
   - Need clarification from stakeholder

2. **Always include vs. opt-in?** Should these fields always appear in the response, or should they be gated behind a query parameter like `?include=scrobbles,country`?

3. **Artist country — which artist?** A record can have multiple artists (collaborations). Should we show country for the main artist only, or all artists? Main artist is simpler and more predictable.
