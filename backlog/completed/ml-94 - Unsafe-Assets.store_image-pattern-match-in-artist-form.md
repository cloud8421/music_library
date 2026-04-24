---
id: ML-94
title: Unsafe Assets.store_image pattern-match in artist form
status: Done
assignee: []
created_date: '2026-04-20 08:58'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/80'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-03 · closed 2026-03-03_

## Priority: Medium

## Description

`lib/music_library_web/live/artist_live/form.ex:303` — Uses `{:ok, asset} = Assets.store_image(image_params)` without wrapping in `case`/`with`. If `store_image` returns an error, the function crashes with a `MatchError` instead of showing a user-friendly error.

## Expected behavior

Wrap in `case` or `with` and handle the error tuple to show a user-friendly message.

## Source

From technical debt audit (2026-02-17), item #7.
<!-- SECTION:DESCRIPTION:END -->
