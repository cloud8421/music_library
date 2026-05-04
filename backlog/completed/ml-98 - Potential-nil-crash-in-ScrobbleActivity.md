---
id: ML-98
title: Potential nil crash in ScrobbleActivity
status: Done
assignee: []
created_date: "2026-04-20 08:58"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/76"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-02-17 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

`lib/music_library/scrobble_activity.ex:70,80,89` — `Enum.find` results are piped directly into `Release.medium_duration/1` without nil guards. If a medium with the specified number isn't found, this crashes with a `FunctionClauseError`.

## Expected behavior

Add nil guards or handle the case where `Enum.find` returns `nil` gracefully.

## Source

From technical debt audit (2026-02-17), item #3.

<!-- SECTION:DESCRIPTION:END -->
