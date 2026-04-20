---
id: ML-59
title: Standardize list separation pattern (divide-y vs space-y)
status: Done
assignee: []
created_date: '2026-04-20 08:54'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/116'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Lists use two different separation approaches:

- **Most lists** use `divide-y divide-zinc-100 dark:divide-zinc-300/20` (visual divider lines)
- **Scrobble rules** (`scrobble_rules_live/index.ex:71`) uses `space-y-4` (gap-based spacing, no dividers)

## Decision needed

Should all lists use `divide-y` for consistency, or is `space-y` acceptable for card-style list items where dividers would feel heavy?
<!-- SECTION:DESCRIPTION:END -->
