---
id: ML-52
title: Collection/Wishlist Show LiveViews duplication
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/123'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-22 · updated 2026-03-22 · closed 2026-03-22_

## Description

`CollectionLive.Show` (611 lines) and `WishlistLive.Show` (462 lines) have near-identical `handle_event` implementations for shared operations: `refresh_musicbrainz_data`, `refresh_cover`, `populate_genres`. The error handling, success messaging, and state management patterns are functionally identical, meeting the project's 3+ duplication extraction threshold.

## Files

- `lib/music_library_web/live/collection_live/show.ex`
- `lib/music_library_web/live/wishlist_live/show.ex`

## Suggested approach

Extract shared record action handlers into a helper module that both LiveViews can delegate to.
<!-- SECTION:DESCRIPTION:END -->
