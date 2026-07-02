---
id: ML-19
title: Circular dependency between Records and Collection/Wishlist
status: To Do
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/160"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-06 · not planned_

## Summary

`Collection` and `Wishlist` call `Records.search_records(base_search(), ...)`, creating a circular dependency where Records is called by modules that exist primarily as query filters on Records.

## Why This Matters

- The only difference between Collection and Wishlist is the base query filter (`purchased_at IS NOT NULL` vs `IS NULL`)
- These aren't independent contexts — they're query filters on Records
- The circular call pattern (Records <- Collection <- Records) makes the dependency graph confusing

## Affected Files

- `lib/music_library/collection.ex` (line 22)
- `lib/music_library/wishlist.ex` (line 20)
- `lib/music_library/records.ex`

## Suggested Fix

Make Collection and Wishlist sub-modules of Records (`Records.Collection`, `Records.Wishlist`) or simple functions within Records that accept a filter parameter.

## Acceptance Criteria

<!-- AC:BEGIN -->

- No circular dependency between context modules
- Collection/Wishlist filtering remains functional

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 No circular dependency between context modules
- [ ] #2 Collection/Wishlist filtering remains functional

<!-- AC:END -->
