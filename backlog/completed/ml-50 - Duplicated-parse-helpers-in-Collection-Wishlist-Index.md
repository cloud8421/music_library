---
id: ML-50
title: Duplicated parse helpers in Collection/Wishlist Index
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/125"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-22 · updated 2026-03-22 · closed 2026-03-22_

## Description

`parse_order/1` and `parse_mode/2` are identical private helper functions duplicated across both index LiveViews.

## Files

- `lib/music_library_web/live/collection_live/index.ex`
- `lib/music_library_web/live/wishlist_live/index.ex`

## Suggested approach

Extract into a shared helper module (e.g. `MusicLibraryWeb.LiveHelpers.Params` which already exists for pagination).

<!-- SECTION:DESCRIPTION:END -->
