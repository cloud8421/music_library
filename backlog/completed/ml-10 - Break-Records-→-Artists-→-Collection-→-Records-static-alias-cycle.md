---
id: ML-10
title: Break Records → Artists → Collection → Records static alias cycle
status: Done
assignee: []
created_date: "2026-04-20 08:49"
updated_date: "2026-04-24 09:49"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/173"
priority: low
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

A three-way compile-connected alias cycle exists between the three context facades. `mix xref graph --format cycles` surfaces it. No runtime cycle (the Records → Artists edge is Oban-async).

## Evidence

```
Records → Artists:  lib/music_library/records.ex:10 (alias)
  Artists.refresh_artist_info_async/1   records.ex:387
  Artists.prune_artist_info_async/1     records.ex:417

Artists → Collection: lib/music_library/artists.ex:10 (alias)
  Collection.collected_artist_ids/0     artists.ex:29 (used inside get_similar_artists/1)

Collection → Records: lib/music_library/collection.ex:9 (alias) + line 7 (import)
  Records.search_records/4, Records.search_records_count/2, Records.essential_fields/0
  import MusicLibrary.Records, only: [order_alphabetically: 0]
```

The compile-time edge in the cycle is `Collection → Records` via `import ..., only: [order_alphabetically: 0]`. `order_alphabetically` is a **macro** (`records.ex:56`), so the import is unavoidably compile-time. `mix xref graph --format cycles --label compile` reports this as a cycle of 15 nodes (3 contexts + `Records.Similarity` + 11 workers), meaning any change to any of those 15 modules triggers recompilation of the entire cycle.

Breaking any other edge in the triangle (including `Artists → Collection`) removes the cycle without needing to eliminate the macro import.

## Relation to #112

#112 fixed the earlier `Records ↔ Artists` bidirectional dependency by moving `collected_artist_ids/0` from `Artists` to `Collection`. That fix made the shape `Records → Artists → Collection → Records` — unidirectional in hops, but still a compile-connected cycle.

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

This removes the `Artists → Collection` edge without moving any behaviour. Within `lib/music_library/`, only `Artists` aliases `Collection` — everything else referencing `Collection` lives in `lib/music_library_web/` (outside the cycle), so this single change is sufficient to break the cycle.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- `mix xref graph --format cycles --label compile` reports no cycle involving Records/Artists/Collection
- `ArtistLive.Show` tests still pass

- [x] #1 `mix xref graph --format cycles --label compile` reports no cycle involving Records/Artists/Collection
- [x] #2 `ArtistLive.Show` tests still pass

<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Removed `alias MusicLibrary.Collection` from `MusicLibrary.Artists` and changed `get_similar_artists/1` to `get_similar_artists/2`, taking the collected artist id set as an argument instead of fetching it inline. The only caller (`ArtistLive.Show`) now computes the set via `Collection.collected_artist_ids()` and passes it in.

`mix xref graph --format cycles --label compile` now reports **no cycles**. The 3-way cycle is gone, and the 15-module compile-connected cycle that previously forced recompilation cascades is broken. A 14-module runtime-only cycle (Records ↔ Artists via Oban-async edges + workers) remains as expected and does not trigger recompilation.

Full test suite (836 tests including 10 in `ArtistLive.ShowTest`) passes. Format and Credo clean.

<!-- SECTION:FINAL_SUMMARY:END -->
