---
id: ML-77
title: Inconsistent alphabetical ordering helpers
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/98'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Low

## Description

`Records` defines an `order_alphabetically()` macro (used by `Collection`), but `OnlineStoreTemplates` and `RecordSets` use raw `fragment("? COLLATE NOCASE ASC", ...)` instead.

### Locations

- `lib/music_library/records.ex:39` — defines macro
- `lib/music_library/collection.ex:52,62,73` — uses macro
- `lib/music_library/online_store_templates.ex:14,20` — raw fragment
- `lib/music_library/record_sets.ex:45` — raw fragment

## Expected behavior

Parameterize the `order_alphabetically` macro to accept a field and share it across all contexts.

## Source

From technical debt audit (2026-03-05).
<!-- SECTION:DESCRIPTION:END -->
