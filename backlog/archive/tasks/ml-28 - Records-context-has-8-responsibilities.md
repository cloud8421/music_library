---
id: ML-28
title: Records context has 8+ responsibilities
status: To Do
assignee: []
created_date: '2026-04-20 08:51'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/151'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-11 · closed 2026-04-11 · not planned_

## Summary

The `Records` context module handles search, genre management, cover art operations, color extraction, embeddings, MusicBrainz data refresh, artist metadata refresh, CRUD, and PubSub notifications — too many concerns in one module.

## Why This Matters

- Hard to navigate and understand at a glance
- Changes to one concern risk affecting others
- Testing is harder when responsibilities are interleaved

## Affected Files

- `lib/music_library/records.ex`

## Suggested Fix

Extract into focused sub-modules:
- `Records.Search` — search operations
- `Records.Metadata` — MusicBrainz sync, genre population
- `Records.Assets` — covers, colors
- `Records.Embeddings` — AI embedding generation

Keep the `Records` module as the public API that delegates to sub-modules.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Each sub-module has a single clear responsibility
- Public API remains unchanged for callers
- No regression in functionality
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Each sub-module has a single clear responsibility
- [ ] #2 Public API remains unchanged for callers
- [ ] #3 No regression in functionality
<!-- AC:END -->
