---
id: ML-48
title: ScrobbleActivity context has zero test coverage
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/127'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-22 · updated 2026-03-23 · closed 2026-03-23_

## Description

`MusicLibrary.ScrobbleActivity` has complex scrobbling logic with multiple branches for release/medium/tracks but no corresponding test file. Prior issues #83 and #106 addressed code quality problems in this module but did not add test coverage.

## File

- `lib/music_library/scrobble_activity.ex`
<!-- SECTION:DESCRIPTION:END -->
