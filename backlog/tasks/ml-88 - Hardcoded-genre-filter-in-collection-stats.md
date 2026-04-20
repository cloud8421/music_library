---
id: ML-88
title: Hardcoded genre filter in collection stats
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/86'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Low

## Description

`lib/music_library/collection.ex:113-114` — Hardcodes filtering out `"rock"` from genre stats because "it's really generic and dwarfs other genres." This should be configurable.

## Expected behavior

Make the excluded genres configurable rather than hardcoded.

## Source

From technical debt audit (2026-02-17), item #13.
<!-- SECTION:DESCRIPTION:END -->
