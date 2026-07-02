---
id: ML-20
title: Missing indexes on JSON extraction queries in ListeningStats
status: To Do
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/159"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-12 · closed 2026-04-12 · not planned_

## Summary

`ListeningStats` filters tracks by `artist.musicbrainz_id` and `album.musicbrainz_id` via JSON extraction, and `Artists` searches by `artist ->> '$.name'` with LIKE. These patterns benefit from expression-based indexes that don't currently exist.

## Evidence

- `lib/music_library/listening_stats.ex` lines 100-105: filtering by `artist.musicbrainz_id` (JSON extraction)
- `lib/music_library/listening_stats.ex` lines 474-478: filtering by `album.musicbrainz_id` and album title
- `lib/music_library/artists.ex` lines 92-96: LIKE search on `artist ->> '$.name'`

## Suggested Fix

Add expression-based indexes on the most frequently queried JSON paths:

```sql
CREATE INDEX idx_tracks_artist_mbid ON tracks(json_extract(artist, '$.musicbrainz_id'));
CREATE INDEX idx_tracks_album_mbid ON tracks(json_extract(album, '$.musicbrainz_id'));
```

Profile queries before and after to confirm impact.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Expression-based indexes exist for hot JSON extraction paths
- Query plans show index usage for filtered ListeningStats queries

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Expression-based indexes exist for hot JSON extraction paths
- [ ] #2 Query plans show index usage for filtered ListeningStats queries

<!-- AC:END -->
