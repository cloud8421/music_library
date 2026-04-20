---
id: ML-69
title: ArgumentError raises in ScrobbleActivity
status: To Do
assignee: []
created_date: '2026-04-20 08:55'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/106'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-12 · updated 2026-04-09 · closed 2026-03-14 · not planned_

## Description

`lib/music_library/scrobble_activity.ex:19,61,116` raises `ArgumentError` when both `started_at` and `finished_at` are provided to scrobble functions. Per Elixir conventions, public API functions should return `{:error, _}` tuples for input validation rather than raising. These functions are called from LiveComponent event handlers where a crash would kill the LiveView process.

## Expected behavior

Return `{:error, :invalid_options}` (or similar) and handle upstream with a user-facing toast message.

## Source

From technical debt audit (2026-03-12).
<!-- SECTION:DESCRIPTION:END -->
