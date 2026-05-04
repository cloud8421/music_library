---
id: ML-65
title: Move scrobble queries out of Records context
status: Done
assignee: []
created_date: "2026-04-20 08:55"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/110"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Problem

`MusicLibrary.Records` directly queries `LastFm.Track` in three places: `get_last_listened_track/1`, `play_count/1`, `scrobbles_for_record_query/1`. This is a cross-domain leak — scrobble data belongs to the listening/stats domain.

## Proposed solution

Move `get_last_listened_track/1` and `play_count/1` into `MusicLibrary.ListeningStats`. Update LiveView callers (`CollectionLive.Show`, `WishlistLive.Show`) to call `ListeningStats` instead of `Records`. Remove `LastFm.Track` alias from `Records`.

## Files involved

- `lib/music_library/records.ex`
- `lib/music_library/listening_stats.ex`
- `lib/music_library_web/live/collection_live/show.ex`
- `lib/music_library_web/live/wishlist_live/show.ex`
- Tests for the above
<!-- SECTION:DESCRIPTION:END -->
