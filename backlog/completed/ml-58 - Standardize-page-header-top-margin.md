---
id: ML-58
title: Standardize page header top margin
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/117"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Page-level section headers use inconsistent top margins:

- Stats sections: `mt-5` (`stats_live/index.ex:20`)
- Maintenance: `mt-2` (`maintenance_live/index.ex:21`)
- TopByPeriod: no margin (`stats_live/top_by_period.ex:23`)

## Suggestion

Pick a standard margin (e.g. `mt-5`) for all page-level h1 section headers.

<!-- SECTION:DESCRIPTION:END -->
