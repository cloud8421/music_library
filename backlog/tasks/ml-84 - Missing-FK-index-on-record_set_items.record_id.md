---
id: ML-84
title: Missing FK index on record_set_items.record_id
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/91'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: High

## Description

`priv/repo/migrations/20260205113055_create_record_set_items.exs` creates indexes on `[:record_set_id]` and `[:record_set_id, :position]`, but NOT on `[:record_id]`.

This means record deletion and cross-set record queries will require a full table scan on `record_set_items`.

## Expected behavior

Add an index on `record_set_items.record_id`:

```elixir
create index(:record_set_items, [:record_id])
```

## Source

From technical debt audit (2026-03-05).
<!-- SECTION:DESCRIPTION:END -->
