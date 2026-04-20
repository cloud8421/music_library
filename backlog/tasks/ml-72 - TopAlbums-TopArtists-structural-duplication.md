---
id: ML-72
title: TopAlbums/TopArtists structural duplication
status: Done
assignee: []
created_date: '2026-04-20 08:55'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/103'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Description

`lib/music_library_web/live/stats_live/top_albums.ex` (201 LOC) and `top_artists.ex` (168 LOC) share near-identical structure: same `mount/1`, `update/2`, `handle_event/3` callbacks; same time-period tab UI; same `assign_async` pattern with `reset: true`. Only the data source and item rendering differ.

Additionally, `top_artists_by_period/1` is `def` (public) while `top_albums_by_period/1` is `defp` (private) — a visibility inconsistency.

## Expected behavior

Consider extracting a parameterized `TopByPeriod` component that accepts data-fetching and rendering callbacks. Fix the `def`/`defp` inconsistency.

## Source

From technical debt audit (2026-03-12).
<!-- SECTION:DESCRIPTION:END -->
