---
id: ML-64
title: Split ScrobbleActivity into focused modules
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/111"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Problem

`MusicLibrary.ScrobbleActivity` bundles three distinct responsibilities: (1) scrobbling to Last.fm, (2) track CRUD and listing, (3) data quality diagnostics. The track listing query is nearly identical to `ListeningStats.recent_activity/2`.

## Proposed solution (Option A)

1. Move track CRUD + listing into `ListeningStats`
2. Keep `ScrobbleActivity` focused on writes (scrobbling releases/mediums/tracks)
3. Move diagnostics to `Maintenance`

## Files involved

- `lib/music_library/scrobble_activity.ex`
- `lib/music_library/listening_stats.ex`
- `lib/music_library/maintenance.ex`
- `lib/music_library_web/live/scrobbled_tracks_live/index.ex`
- `lib/music_library_web/live/maintenance_live/index.ex`
- Tests for all of the above
<!-- SECTION:DESCRIPTION:END -->
