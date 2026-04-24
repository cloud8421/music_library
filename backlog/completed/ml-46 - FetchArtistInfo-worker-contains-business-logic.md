---
id: ML-46
title: FetchArtistInfo worker contains business logic
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/131'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

`FetchArtistInfo` worker (`lib/music_library/worker/fetch_artist_info.ex:15-21`) contains a private `regenerate_record_embeddings/1` function that orchestrates cross-context work (fetching artist records, then generating embeddings for each). Per project conventions, workers should be thin wrappers that delegate to context modules.

## Expected behavior

Extract `regenerate_record_embeddings/1` into a context function (e.g. `Records.regenerate_artist_embeddings/1` or `Artists.regenerate_record_embeddings/1`).

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
