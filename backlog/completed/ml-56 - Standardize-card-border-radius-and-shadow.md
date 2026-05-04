---
id: ML-56
title: Standardize card border-radius and shadow
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/119"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Card/panel components use inconsistent rounding and shadows:

- Record set cards (`record_set_live/index.ex:274`): `rounded-lg`, no shadow
- Stats top-by-period (`stats_live/top_by_period.ex:75`): `rounded-md` with `shadow-sm`

## Suggestion

Pick one card style (e.g. `rounded-lg` without shadow, or `rounded-md` with `shadow-sm`) and apply consistently.

<!-- SECTION:DESCRIPTION:END -->
