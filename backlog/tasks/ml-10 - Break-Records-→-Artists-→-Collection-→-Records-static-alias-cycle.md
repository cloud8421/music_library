---
id: ML-10
title: Break Records → Artists → Collection → Records static alias cycle
status: To Do
assignee: []
created_date: '2026-04-20 08:49'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/173'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

A three-way compile-time alias cycle exists between the three context facades. `mix xref graph --format cycles` surfaces it. No runtime cycle (the Records → Artists edge is Oban-async).

## Evidence

```
Records → Artists:  lib/music_library/records.ex:10 (alias)
  Artists.refresh_artist_info_async/1   records.ex:385
  Artists.prune_artist_info_async/1     records.ex:415

Artists → Collection: lib/music_library/artists.ex:10 (alias)
  Collection.collected_artist_ids/0     artists.ex:29 (used inside get_similar_artists/1)

Collection → Records: lib/music_library/collection.ex:9 (alias)
  Records.search_records/4, Records.search_records_count/2, Records.essential_fields/0
```

## Relation to #112

#112 fixed the earlier `Records ↔ Artists` bidirectional dependency by moving `collected_artist_ids/0` from `Artists` to `Collection`. That fix made the shape `Records → Artists → Collection → Records` — unidirectional in hops, but still a compile-time cycle.

## Fix

Parametrize `Artists.get_similar_artists/1` to receive `collected_artist_ids` instead of fetching inline:

```elixir
# in Artists
def get_similar_artists(artist, collected_artist_ids) do
  # ... use the set passed in
end

# in the caller (ArtistLive.Show)
collected = Collection.collected_artist_ids()
similar = Artists.get_similar_artists(artist, collected)
```

This removes the `Artists → Collection` edge without moving any behaviour, and the "which are in the collection?" filtering becomes a caller concern.

## Acceptance Criteria
<!-- AC:BEGIN -->
- `mix xref graph --format cycles` reports no cycles involving these three modules
- `ArtistLive.Show` tests still pass
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `mix xref graph --format cycles` reports no cycles involving these three modules
- [ ] #2 `ArtistLive.Show` tests still pass
<!-- AC:END -->
