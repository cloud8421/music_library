---
id: ML-66
title: Large modules unchanged since last audit
status: To Do
assignee: []
created_date: '2026-04-20 08:55'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/109'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-12 · updated 2026-04-09 · closed 2026-03-16 · not planned_

## Description

The four modules flagged in #99 remain at the same size:

| File | LOC |
|------|-----|
| `lib/music_library_web/live/artist_live/show.ex` | 804 |
| `lib/music_library_web/components/record_components.ex` | 761 |
| `lib/music_library_web/components/record_form.ex` | 652 |
| `lib/music_brainz/api.ex` | 564 |

Not urgent — only refactor when new feature work naturally touches these files.

## Expected behavior

Monitor and consider extraction when adding new features to these modules.

## Source

From technical debt audit (2026-03-12). Continuation of #99.
<!-- SECTION:DESCRIPTION:END -->
