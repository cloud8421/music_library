---
id: ML-141
title: Support records with accents
status: Done
assignee: []
created_date: '2026-04-20 09:00'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/7'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2024-12-07 · updated 2024-12-07 · closed 2024-12-07_

SQLite's collation functions don't by default collapse accented characters into their non-accented variants. For example, an artist with sort name `Åkerfeldt, Mikael` is appended at the bottom instead of being grouped with `A`.

The `records_search_index` table behaves correctly (searching `Aker` matches the artist), but alphabetical sorting/grouping is broken for non-ASCII sort names.

Fix: ensure non-ASCII artist records are slotted at the correct alphabetical position.
<!-- SECTION:DESCRIPTION:END -->
