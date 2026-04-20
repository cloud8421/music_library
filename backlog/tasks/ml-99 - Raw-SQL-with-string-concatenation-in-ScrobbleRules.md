---
id: ML-99
title: Raw SQL with string concatenation in ScrobbleRules
status: Done
assignee: []
created_date: '2026-04-20 08:58'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/75'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

`lib/music_library/scrobble_rules.ex` — Four `apply_all_*_rules` functions (lines 398-598) build CASE/WHEN and WHERE IN clauses via string concatenation and execute with `Repo.query/2`. Values are properly parameterized, but the SQL structure (placeholders, CASE clauses) is built via string interpolation, making it harder to maintain and test than Ecto query builders.

## Expected behavior

Use Ecto query builders or a safer SQL construction approach to improve maintainability and testability.

## Source

From technical debt audit (2026-02-17), item #2.
<!-- SECTION:DESCRIPTION:END -->
