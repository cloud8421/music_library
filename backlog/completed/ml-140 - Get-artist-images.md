---
id: ML-140
title: Get artist images
status: Done
assignee: []
created_date: "2026-04-20 09:00"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/23"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2025-04-22 · updated 2025-04-29 · closed 2025-04-29_

Fetch artist images via MusicBrainz url-rels → Discogs artist endpoint. Implementation checklist (all completed):

- Discogs api client
- MusicBrainz `get_artist/1` with result parser
- `ArtistInfo` db schema and migration
- Context function to fetch and store `ArtistInfo`
- Background job to fetch and store `ArtistInfo`
- Extract image URL from Discogs artist
- Store/hash image from Discogs artist
- Endpoint to serve artist images
- Show artist image in artist page
- Populate artist info when new artist is added
- Cascade deletions
- Tests
<!-- SECTION:DESCRIPTION:END -->
