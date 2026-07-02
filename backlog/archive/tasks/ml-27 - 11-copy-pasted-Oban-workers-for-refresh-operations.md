---
id: ML-27
title: 11 copy-pasted Oban workers for refresh operations
status: To Do
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/152"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-12 · closed 2026-04-12 · not planned_

## Summary

Single-record refresh workers and their batch counterparts are nearly identical, differing only in the delegated function call. 11 workers share the same ~10-line structure.

## Affected Workers

Single-record (6): `ArtistRefreshDiscogsData`, `ArtistRefreshMusicBrainzData`, `ArtistRefreshWikipediaData`, `FetchArtistLastFmData`, `RecordRefreshMusicBrainzData`, `GenerateRecordEmbedding`

Batch (5): `ArtistRefreshAllDiscogsData`, `ArtistRefreshAllMusicBrainzData`, `ArtistRefreshAllWikipediaData`, `RecordRefreshAllMusicBrainzData`, `RecordGenerateAllEmbeddings`

## Suggested Fix

Consider a generic worker pattern or macro that accepts the delegated function as a parameter, reducing boilerplate while keeping each worker as a distinct module for queue routing.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Boilerplate is reduced
- Each worker remains individually identifiable for Oban queue routing and monitoring
- No change in worker behaviour

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Boilerplate is reduced
- [ ] #2 Each worker remains individually identifiable for Oban queue routing and monitoring
- [ ] #3 No change in worker behaviour

<!-- AC:END -->
