---
id: ML-91
title: ScrobbleActivity is a god module (557 lines)
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/83'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-02 · closed 2026-03-02_

## Priority: Medium

## Description

`lib/music_library/scrobble_activity.ex` handles scrobbling, activity tracking, artist stats, album stats, track CRUD, and search. The multiple `get_top_*` functions (lines 184-412) follow similar patterns and could be extracted into focused modules.

## Expected behavior

Extract cohesive groups of functions into focused modules (e.g., stats, search, track CRUD).

## Source

From technical debt audit (2026-02-17), item #10.
<!-- SECTION:DESCRIPTION:END -->
