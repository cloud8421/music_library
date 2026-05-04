---
id: ML-83
title: Duplicated apply_fallback_index across 5 LiveViews
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/92"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

The `apply_fallback_index/2` function is duplicated identically across 5 LiveViews, differing only in the stream key name:

- `lib/music_library_web/live/collection_live/index.ex:240`
- `lib/music_library_web/live/wishlist_live/index.ex:211`
- `lib/music_library_web/live/scrobble_rules_live/index.ex:188`
- `lib/music_library_web/live/record_set_live/index.ex:342`
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex:255`

## Expected behavior

Extract to a shared helper, parameterizing the stream key name.

## Source

From technical debt audit (2026-03-05).

<!-- SECTION:DESCRIPTION:END -->
