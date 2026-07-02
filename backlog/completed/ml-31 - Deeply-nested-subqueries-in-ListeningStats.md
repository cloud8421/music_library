---
id: ML-31
title: Deeply nested subqueries in ListeningStats
status: Done
assignee: []
created_date: "2026-04-20 08:52"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/148"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-11 · closed 2026-04-11_

## Summary

`ListeningStats` builds deeply nested subqueries that join to Collection and Wishlist subqueries, creating multi-level query nesting that becomes expensive with high track volume.

## Why This Matters

Three query builders create multi-level nested subqueries:

- `tracks_with_record_info_query` (lines 344-363) — 3 left joins to subqueries containing their own subqueries
- `top_albums_base_query` (lines 365-388) — same nested pattern for album aggregation
- `top_artists_base_query` (lines 390-404) — third-order subqueries

These are used by `list_tracks`, `recent_activity`, and `get_top_albums_by_period` — high-traffic queries that will degrade as track count grows.

Additionally, `unique_collected_releases_query` and `unique_wishlisted_releases_query` (lines 406-424) duplicate identical grouping logic.

## Affected Files

- `lib/music_library/listening_stats.ex`

## Suggested Fix

- Simplify query nesting by flattening joins or using CTEs
- Consider materialized views for the collection/wishlist release lookups
- Deduplicate the `unique_*_releases_query` helpers

## Acceptance Criteria

<!-- AC:BEGIN -->

- Query plans for `list_tracks` and `recent_activity` show reduced nesting
- No regression in query results
- Benchmarks show comparable or better performance

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Query plans for `list_tracks` and `recent_activity` show reduced nesting
- [ ] #2 No regression in query results
- [ ] #3 Benchmarks show comparable or better performance

<!-- AC:END -->
