---
id: ML-85
title: Unvalidated String.to_integer() in HTTP endpoints
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/90"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Critical

## Description

Multiple locations use `String.to_integer()` on user-supplied input without error handling. This crashes with `ArgumentError` on non-numeric input, causing 500 errors.

### Affected locations

- `lib/music_library_web/controllers/collection_controller.ex:34,39` — API endpoint, externally reachable
- `lib/music_library_web/live/scrobble_live/show.ex:165` — LiveView event handler
- `lib/music_library_web/components/release.ex:285,327` — LiveComponent event handler
- `lib/music_brainz/artist.ex:56` — External API data parsing
- `lib/last_fm/track.ex:77` and `lib/last_fm/artist.ex:71` — External API data parsing

## Expected behavior

Use `Integer.parse/1` with proper error handling, similar to `MusicLibraryWeb.LiveHelpers.Params.parse_page/1` which already does this correctly.

## Source

From technical debt audit (2026-03-05).

<!-- SECTION:DESCRIPTION:END -->
