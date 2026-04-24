---
id: ML-78
title: Commented-out code in error_json.ex
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/97'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Low

## Description

`lib/music_library_web/controllers/error_json.ex:11-13` contains a commented-out function clause for 500 error rendering. Per project conventions, dead code should be removed.

## Expected behavior

Either remove the commented-out code or restore it if needed.

## Source

From technical debt audit (2026-03-05).
<!-- SECTION:DESCRIPTION:END -->
