---
id: ML-29
title: Collection/Wishlist index LiveView duplication
status: Done
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/150"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-13 · closed 2026-04-13_

## Summary

`CollectionLive.Index` (359 lines) and `WishlistLive.Index` (338 lines) share ~40% identical code including `apply_action/3`, `load_and_assign_records/2`, `order_path/2`, `back_path/2`, search event handling, and filter/pagination markup.

## Why This Matters

- Any change to index behaviour (pagination, search, display modes, ordering) must be applied twice
- Bug fixes in one may be missed in the other
- #125 addressed the duplicated parse helpers, but the broader structural duplication remains

## Affected Files

- `lib/music_library_web/live/collection_live/index.ex`
- `lib/music_library_web/live/wishlist_live/index.ex`

## Suggested Fix

Extract shared index behaviour into a `LiveHelpers` module or use a shared base pattern that both LiveViews delegate to, parameterizing only the differences (base query filter, routes, section name).

## Acceptance Criteria

<!-- AC:BEGIN -->

- Shared logic lives in one place
- Both index pages retain their current functionality
- Adding a new shared feature (e.g., new sort option) requires changes in one location
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Shared logic lives in one place
- [ ] #2 Both index pages retain their current functionality
- [ ] #3 Adding a new shared feature (e.g., new sort option) requires changes in one location
<!-- AC:END -->
