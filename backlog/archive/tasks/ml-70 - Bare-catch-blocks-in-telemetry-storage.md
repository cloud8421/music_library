---
id: ML-70
title: Bare catch blocks in telemetry storage
status: To Do
assignee: []
created_date: '2026-04-20 08:55'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/105'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-12 · updated 2026-04-09 · closed 2026-03-16 · not planned_

## Description

`lib/music_library_web/telemetry/storage.ex:106-107,123-124` uses bare catch blocks that silently swallow all errors. While reasonable for telemetry resilience (ETS table may not exist during shutdown), they make debugging harder when the table is unexpectedly missing during normal operation.

## Expected behavior

Add `Logger.debug` calls inside the catch blocks to aid troubleshooting ETS table issues without affecting production resilience.

## Source

From technical debt audit (2026-03-12).
<!-- SECTION:DESCRIPTION:END -->
