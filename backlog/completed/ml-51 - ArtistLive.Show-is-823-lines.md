---
id: ML-51
title: ArtistLive.Show is 823 lines
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/124"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-22 · updated 2026-03-22 · closed 2026-03-22_

## Description

`ArtistLive.Show` is the largest LiveView in the codebase at 823 lines. It handles artist metadata, discography, image search/upload, notes, chat, similar artists, biography building, and multiple refresh operations.

Business logic like `build_biography/1` (51 lines of biography processing with link removal and content rendering) could be extracted into a helper module to improve testability.

## File

- `lib/music_library_web/live/artist_live/show.ex`
<!-- SECTION:DESCRIPTION:END -->
