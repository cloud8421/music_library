---
id: ML-95
title: Process.sleep for rate limiting in Oban workers
status: Done
assignee: []
created_date: "2026-04-20 08:58"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/79"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-02-17 · updated 2026-03-02 · closed 2026-03-02_

## Priority: Medium

## Description

Three workers use `Process.sleep` to rate-limit API calls:

| Worker                         | File                                                              | Sleep  |
| ------------------------------ | ----------------------------------------------------------------- | ------ |
| `ArtistRefreshMusicBrainzData` | `lib/music_library/worker/artist_refresh_music_brainz_data.ex:8`  | 500ms  |
| `ArtistRefreshDiscogsData`     | `lib/music_library/worker/artist_refresh_discogs_data.ex:8`       | 1000ms |
| `RecordRefreshMusicBrainzData` | `lib/music_library/worker/record_refresh_music_brainz_data.ex:12` | 500ms  |

This blocks the worker process during the sleep, preventing Oban from using it for other jobs.

## Expected behavior

Consider using Oban's `rate_limit` plugin or queue-level concurrency limits instead.

## Source

From technical debt audit (2026-02-17), item #6.

<!-- SECTION:DESCRIPTION:END -->
