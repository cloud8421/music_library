---
id: ML-62
title: Route Search artist queries through Artists context
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/113"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Problem

`MusicLibrary.Search.search_artists/2` and `search_artists_count/1` build their own Ecto queries directly joining `Records.ArtistRecord` to `Artists.ArtistInfo`, bypassing the `Artists` context entirely. This violates the project convention that context modules own all queries.

## Proposed solution

Add `search_by_name/2` and `search_by_name_count/1` to `MusicLibrary.Artists`, then have `Search.search_artists/2` and `Search.search_artists_count/1` delegate to them. Remove `ArtistRecord` and `ArtistInfo` aliases from `Search`.

## Files involved

- `lib/music_library/artists.ex` (add functions)
- `lib/music_library/search.ex` (delegate, remove aliases)
- Tests for `Artists` and `Search`
<!-- SECTION:DESCRIPTION:END -->
