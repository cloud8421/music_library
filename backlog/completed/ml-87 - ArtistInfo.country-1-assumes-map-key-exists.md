---
id: ML-87
title: ArtistInfo.country/1 assumes map key exists
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/87"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Low

## Description

`lib/music_library/artists/artist_info.ex:34-35` — Pattern matches on `%{"area" => area} = artist_info.musicbrainz_data` which crashes with `MatchError` if the `"area"` key is missing.

## Expected behavior

Use `Map.get/3` with a default value instead of pattern matching.

## Source

From technical debt audit (2026-02-17), item #14.

<!-- SECTION:DESCRIPTION:END -->
