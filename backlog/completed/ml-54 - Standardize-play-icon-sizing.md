---
id: ML-54
title: Standardize play icon sizing
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/121"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

The play/scrobble icon (`hero-play`) uses three different sizing approaches:

- `h-4 w-4` in `scrobble_live/show.ex:90`, `release.ex`
- `h-5 w-5` in `collection_live/show.ex:57` (button group)
- `class="icon"` (default) in `scrobble_rules_live/index.ex:38`

## Suggestion

The button group context (`h-5 w-5`) vs dropdown/inline context (`h-4 w-4`) might be intentional. If so, document the sizing convention. The `class="icon"` usage should align with one of these.

<!-- SECTION:DESCRIPTION:END -->
