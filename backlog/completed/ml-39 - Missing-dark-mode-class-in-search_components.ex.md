---
id: ML-39
title: Missing dark mode class in search_components.ex
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/138'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

At `lib/music_library_web/components/search_components.ex:51`, a paragraph has `text-zinc-500` without the corresponding `dark:text-zinc-400` class. Adjacent elements at lines 45 and 48 correctly pair light/dark classes.

## Expected behavior

Add `dark:text-zinc-400` to the class list at line 51, consistent with the project convention of always pairing dark mode variants.

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
