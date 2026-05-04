---
id: ML-63
title: Break bidirectional dependency between Records and Artists
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/112"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Problem

`Records` and `Artists` have a bidirectional dependency: Records → Artists (async Oban calls on create/delete) and Artists → Records (`get_collected_artist_ids/0` joins `Records.Record` directly). The direct schema query from Artists → Records is a hard compile-time dependency on another context's schema.

## Proposed solution

Move `get_collected_artist_ids/0` into `Collection` (which already owns the `purchased_at IS NOT NULL` scoping concern). Then `Artists.get_similar_artists/1` calls `Collection.collected_artist_ids()` instead. Accept `ArtistRecord` as a shared read-only schema used by both domains.

## Steps

1. Add `collected_artist_ids/0` to `MusicLibrary.Collection`
2. Update `Artists.get_similar_artists/1` to call `Collection.collected_artist_ids()`
3. Remove `Records.Record` alias from `Artists`
4. Remove the private `get_collected_artist_ids/0` from `Artists`
5. Update tests

## Files involved

- `lib/music_library/artists.ex`
- `lib/music_library/collection.ex`
- Tests for `Artists` and `Collection`
<!-- SECTION:DESCRIPTION:END -->
