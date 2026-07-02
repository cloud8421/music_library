---
id: ML-23
title: StatsLive.Index runs 4+ sequential queries in mount
status: To Do
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/156"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-09 · not planned_

## Summary

`StatsLive.Index` mount calls `get_latest_record()`, `count_records_by_artist()`, `count_records_by_genre()`, `count_records_by_release_year()`, and more as separate sequential queries with no batching or async loading.

## Why This Matters

- Each query is a separate database round-trip
- Mount blocks until all queries complete, delaying initial page render
- Lines 54-91 assign 9+ data structures simultaneously

## Affected Files

- `lib/music_library_web/live/stats_live/index.ex` (lines 54-91)

## Suggested Fix

Use `start_async` or `assign_async` to load stats data concurrently after mount, showing placeholder/loading states for each section.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Stats page initial render is faster
- Data loads concurrently where possible
- Loading states are shown while data is fetched

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Stats page initial render is faster
- [ ] #2 Data loads concurrently where possible
- [ ] #3 Loading states are shown while data is fetched

<!-- AC:END -->
