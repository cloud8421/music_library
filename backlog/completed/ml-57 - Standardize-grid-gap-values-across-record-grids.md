---
id: ML-57
title: Standardize grid gap values across record grids
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/118"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Different record grid contexts use different vertical gap values:

- Main record grid (`record_components.ex:251`): `gap-y-8`
- Similar records grid (`record_components.ex:486`): `gap-y-6`
- Record set thumbnails (`record_set_live/index.ex:330`): `gap-3`

## Decision needed

Should all record grids share a consistent `gap-y` value, or are these intentional density differences for different contexts?

<!-- SECTION:DESCRIPTION:END -->
