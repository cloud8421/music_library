---
id: ML-89
title: Random data in test fixtures
status: To Do
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/85'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06 · not planned_

## Priority: Low

## Description

`test/support/fixtures/music_library/records.ex` uses `Enum.random/1` (lines 74, 91, 93) and `:rand.uniform/1` (line 86) for generating test data (artist names, titles, formats, genres). This can make test failures harder to reproduce.

## Expected behavior

Consider using deterministic sequences or seeded randomness for reproducible tests.

## Source

From technical debt audit (2026-02-17), item #12.
<!-- SECTION:DESCRIPTION:END -->
