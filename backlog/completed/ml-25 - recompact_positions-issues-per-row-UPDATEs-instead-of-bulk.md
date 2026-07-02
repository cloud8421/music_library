---
id: ML-25
title: recompact_positions issues per-row UPDATEs instead of bulk
status: Done
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/154"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-06 · closed 2026-04-06_

## Summary

`RecordSets.recompact_positions/1` fetches all items into memory and issues individual UPDATE queries for each item whose position changed. The same module already demonstrates a bulk UPDATE pattern in `reorder_records_in_set/2`.

## Why This Matters

- For a record set with N items, this can issue up to N individual UPDATE queries
- The same module's `reorder_records_in_set/2` (lines 142-157) uses a single bulk UPDATE with CASE expressions — proving the better pattern is already known

## Affected Files

- `lib/music_library/record_sets.ex` (lines 239-254)

## Suggested Fix

Rewrite `recompact_positions/1` to use a single `UPDATE ... CASE` statement, consistent with `reorder_records_in_set/2`.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Position recompaction uses a single bulk UPDATE
- Positions are correctly reassigned with no gaps
- No regression in ordering behaviour

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Position recompaction uses a single bulk UPDATE
- [ ] #2 Positions are correctly reassigned with no gaps
- [ ] #3 No regression in ordering behaviour

<!-- AC:END -->
