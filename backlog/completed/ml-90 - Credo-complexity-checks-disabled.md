---
id: ML-90
title: Credo complexity checks disabled
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/84"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Low

## Description

`.credo.exs` disables `CyclomaticComplexity`, `Nesting`, and `ModuleDoc` checks. Some functions (e.g., `ScrobbleActivity.recent_activity` at ~57 lines) would benefit from the complexity checks being active.

## Expected behavior

Re-enable complexity checks and refactor flagged functions.

## Source

From technical debt audit (2026-02-17), item #11.

<!-- SECTION:DESCRIPTION:END -->
