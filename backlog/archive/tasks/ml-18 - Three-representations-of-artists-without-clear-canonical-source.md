---
id: ML-18
title: Three representations of artists without clear canonical source
status: To Do
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/161"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-08 · not planned_

## Summary

Artist data exists in three different forms with no clear canonical source:

1. `Record` embeds `:artists` (embedded schema in record)
2. `ArtistRecord` — separate lookup table/view
3. `ArtistInfo` — external metadata store

## Why This Matters

- Unclear which representation is authoritative for a given use case
- Updates to one representation don't automatically propagate to others
- New developers must understand all three to work with artist data

## Affected Files

- `lib/music_library/records/record.ex` (embedded `:artists`)
- `lib/music_library/records/artist_records.ex`
- `lib/music_library/artists/artist_info.ex`

## Suggested Fix

Document the purpose and canonical use case for each representation. Consider whether `ArtistRecord` (DB view) can be simplified or whether the embedded artists on Record should be the single source for record-artist relationships.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Clear documentation of each representation's purpose
- Reduced confusion about which to use in new features

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Clear documentation of each representation's purpose
- [ ] #2 Reduced confusion about which to use in new features

<!-- AC:END -->
