---
id: ML-24
title: RecordComponents is 755 lines with 40+ mixed functions
status: Done
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/155"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-12 · closed 2026-04-12_

## Summary

`RecordComponents` contains 40+ functions mixing display components (grids, lists), formatting helpers (badges, text), and structural elements (debug sheets, tooltips). At 755 lines it is difficult to navigate.

## Why This Matters

- `record_list` (96 lines) and `record_grid` (262 lines) share ~50% boilerplate for dropdown/action menus
- Formatting helpers like `format_badge/1` and `format_as_text/1` are interleaved with display components
- Adding a new record display variant requires reading through the entire module

## Affected Files

- `lib/music_library_web/components/record_components.ex`

## Suggested Fix

Split into focused component modules:

- `RecordComponents.Grid` / `RecordComponents.List` — display layouts
- `RecordComponents.Actions` — shared dropdown/action menus
- Keep `RecordComponents` for simple helpers and badges

## Acceptance Criteria

<!-- AC:BEGIN -->

- Each module has a clear, focused purpose
- Shared action menu markup lives in one place
- No regression in rendering
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Each module has a clear, focused purpose
- [ ] #2 Shared action menu markup lives in one place
- [ ] #3 No regression in rendering
<!-- AC:END -->
