---
id: ML-67
title: Credo ModuleDoc check still disabled
status: Done
assignee: []
created_date: "2026-04-20 08:55"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/108"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-03-13 · closed 2026-03-13_

## Description

`.credo.exs:10` disables `Credo.Check.Readability.ModuleDoc`. The `Nesting` check was re-enabled per #84, but `ModuleDoc` remains disabled and `CyclomaticComplexity` was removed entirely (not listed).

## Expected behavior

Consider re-enabling `ModuleDoc` (possibly with exclusions for specific module patterns like LiveComponents) and adding `CyclomaticComplexity` back with an appropriate threshold.

## Source

From technical debt audit (2026-03-12). Residual from #84.

<!-- SECTION:DESCRIPTION:END -->
