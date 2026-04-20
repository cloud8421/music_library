---
id: ML-76
title: Large modules approaching refactoring threshold
status: To Do
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/99'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-06 · closed 2026-03-06 · not planned_

## Priority: Low

## Description

Several modules are approaching or exceeding a reasonable size threshold and may benefit from extraction:

- `lib/music_library_web/live/artist_live/show.ex` — 804 LOC
- `lib/music_library_web/components/record_components.ex` — 761 LOC
- `lib/music_library_web/components/record_form.ex` — 649 LOC
- `lib/music_brainz/api.ex` — 564 LOC

Previously listed `lib/music_library/scrobble_rules.ex` was reduced from 819 to 543 LOC and no longer qualifies.

## Expected behavior

Monitor these modules and consider extraction when adding new features touches them. Not urgent — only refactor when it naturally fits the work being done.

## Source

From technical debt audit (2026-03-05), updated 2026-03-06.
<!-- SECTION:DESCRIPTION:END -->
