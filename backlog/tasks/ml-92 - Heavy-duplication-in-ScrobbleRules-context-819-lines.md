---
id: ML-92
title: Heavy duplication in ScrobbleRules context (819 lines)
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/82'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-02 · closed 2026-03-02_

## Priority: Medium

## Description

`lib/music_library/scrobble_rules.ex` — The following function pairs share near-identical implementations with the only difference being whether they filter by tracks:

- `apply_all_album_rules/1` (398-432) vs `apply_all_album_rules/2` (449-490)
- `apply_all_artist_rules/1` (504-540) vs `apply_all_artist_rules/2` (557-598)
- `apply_all_rules/0` (613-657) vs `apply_all_rules/1` (678-718)

Similarly, `apply_album_rule/1` vs `/2` and `apply_artist_rule/1` vs `/2` share the same SQL-building logic.

## Expected behavior

Consolidate with optional track-filtering parameters to reduce duplication.

## Source

From technical debt audit (2026-02-17), item #9.
<!-- SECTION:DESCRIPTION:END -->
