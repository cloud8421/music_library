---
id: ML-45
title: Inconsistent fetch_* vs refresh_* naming in Artists context
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/132'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

The `Artists` context mixes `fetch_*` and `refresh_*` prefixes for the same semantic operation (retrieve external data and upsert locally), with no clear distinction:

- `fetch_artist_info/1` (line 139)
- `refresh_musicbrainz_data/1` (line 159)
- `refresh_discogs_data/1` (line 174)
- `fetch_wikipedia_data/1` (line 199)
- `refresh_wikipedia_data/1` (line 218) — literally an alias for `fetch_wikipedia_data/1`
- `fetch_image/1` (line 249)
- `fetch_lastfm_data/1` (line 264)

## Expected behavior

Standardize on one naming convention. Since `Records` context uses only `refresh_*`, aligning Artists to `refresh_*` would be the consistent choice.

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
