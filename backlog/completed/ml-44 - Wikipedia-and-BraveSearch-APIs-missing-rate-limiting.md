---
id: ML-44
title: Wikipedia and BraveSearch APIs missing rate limiting
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/133'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

MusicBrainz, LastFm, and Discogs API modules all attach `Req.RateLimiter` to their HTTP clients, but Wikipedia (`lib/wikipedia/api.ex`) and BraveSearch (`lib/brave_search/api.ex`) do not.

This is inconsistent with the pattern used by the other three APIs. While the architecture docs list these as having no rate limit, adding rate limiting would be good API citizenship and consistent with the codebase pattern.

## Expected behavior

Attach `Req.RateLimiter` with appropriate cooldown values to both Wikipedia.API and BraveSearch.API request builders.

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
