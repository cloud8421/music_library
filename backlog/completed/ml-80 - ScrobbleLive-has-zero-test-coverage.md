---
id: ML-80
title: ScrobbleLive has zero test coverage
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/95"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

Both ScrobbleLive modules have no test files:

- `lib/music_library_web/live/scrobble_live/index.ex` (237 LOC) — MusicBrainz release search
- `lib/music_library_web/live/scrobble_live/show.ex` (226 LOC) — Track selection and scrobbling

These are non-trivial LiveViews with event handling, async operations, and external API integration.

## Expected behavior

Add test files covering at least the happy paths for search, selection, and scrobbling flows.

## Source

From technical debt audit (2026-03-05).

<!-- SECTION:DESCRIPTION:END -->
