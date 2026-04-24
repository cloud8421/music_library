---
id: ML-55
title: Standardize stats dashboard gap sizes
status: Done
assignee: []
created_date: '2026-04-20 08:54'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/120'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Within the stats dashboard (`stats_live/index.ex`), multiple gap sizes are used for similar grid sections:

- Line 23: `gap-5` (counter cards)
- Line 44: `gap-x-5` (formats/types)
- Line 69: `gap-5` (top artists/albums)
- Line 264: `gap-4` (scrobble activity)

## Suggestion

Use a single gap value (e.g. `gap-5`) across all stats grid sections for visual consistency.
<!-- SECTION:DESCRIPTION:END -->
