---
id: ML-107
title: Regular job to cleanup asset cache
status: Done
assignee: []
created_date: '2026-04-20 08:59'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/59'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2025-11-07 · updated 2025-11-07 · closed 2025-11-07_

This query returns the hash of all orphan assets

```sql
SELECT hash
FROM assets
LEFT JOIN records on records.cover_hash == assets.hash
LEFT JOIN artist_infos on artist_infos.image_data_hash == assets.hash
WHERE records.id IS NULL AND artist_infos.id IS NULL;
```
<!-- SECTION:DESCRIPTION:END -->
