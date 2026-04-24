---
id: ML-43
title: Wikipedia.Config missing @enforce_keys
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/134'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

All API Config modules use `@enforce_keys` to enforce required struct fields at compile time, but `Wikipedia.Config` (`lib/wikipedia/config.ex:7`) does not declare `@enforce_keys`.

## Expected behavior

Add `@enforce_keys [:user_agent]` (or whichever fields are required) to `Wikipedia.Config`, consistent with all other API configs.

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
