---
id: ML-41
title: "ArtistInfo changeset uniquely casts :id field"
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/136"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

`ArtistInfo.changeset/2` (`lib/music_library/artists/artist_info.ex:28`) includes `:id` in its cast list. No other schema in the codebase casts its primary key field.

This is likely intentional since artist IDs come from MusicBrainz, but the pattern is unique and undocumented. If intentional, a comment explaining why would help.

## Found during

Codebase consistency audit (2026-03-25)

<!-- SECTION:DESCRIPTION:END -->
