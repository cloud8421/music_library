---
id: ML-30
title: Silent error suppression in Artists.refresh_lastfm_data/1
status: Done
assignee: []
created_date: '2026-04-20 08:51'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/149'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-05 · closed 2026-04-05_

## Summary

`Artists.refresh_lastfm_data/1` returns `{:ok, artist_info}` when the Last.fm API call fails, silently swallowing the error and masking problems.

## Why This Matters

- Line 271-272: `{:error, _reason} -> {:ok, artist_info}` hides all Last.fm failures
- Called from `FetchArtistInfo` worker, which proceeds to the next step assuming success
- Makes it impossible to detect persistent Last.fm API issues from job results
- Inconsistent with the project convention that non-fatal enrichment failures should log a warning

## Affected Files

- `lib/music_library/artists.ex` (lines 258-273)

## Suggested Fix

Follow the project's `best_effort_*` pattern: log a warning and return the unchanged struct, but make the suppression explicit and observable.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Last.fm API failures are logged as warnings
- Callers can still proceed without the Last.fm data
- Monitoring/logs reflect when Last.fm enrichment fails
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Last.fm API failures are logged as warnings
- [ ] #2 Callers can still proceed without the Last.fm data
- [ ] #3 Monitoring/logs reflect when Last.fm enrichment fails
<!-- AC:END -->
