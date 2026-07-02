---
id: ML-34
title: Make record creation resilient to color extraction failure
status: Done
assignee: []
created_date: "2026-04-20 08:52"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/144"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-30 · updated 2026-03-30 · closed 2026-03-30_

## Summary

`Records.create_record/1` inserts the record before post-processing and then hard-matches the color extraction result, so a color extraction failure can crash after the record is already persisted.

## Why This Matters

This can leave partially-applied state: the record is committed, the caller sees a crash instead of a tuple result, and follow-up work can be skipped or interrupted.

## Evidence

- `do_create_record/1` inserts the record first.
- `create_record/1` then runs `{:ok, record} = maybe_extract_colors(record)`.
- `maybe_extract_colors/1` delegates to `extract_colors/1`, which can return `{:error, term()}`.
- The function only returns `{:ok, record}` or `{:error, changeset}` in the happy insert path, but can actually raise after commit.

## Affected Files

- `lib/music_library/records.ex`
- `test/music_library/records_test.exs`

## Suggested Fix

Refactor `create_record/1` so post-insert enrichment is failure-tolerant and consistent with the public contract. Reasonable options: treat color extraction as best-effort and continue without crashing; move the enrichment into an explicit background step; or wrap creation plus required follow-up in a transaction if failure must abort the whole operation.

## Acceptance Criteria

<!-- AC:BEGIN -->

- `create_record/1` never raises on color extraction failure.
- The function returns a documented result tuple for both success and failure paths.
- Tests cover a failed color extraction scenario.

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `create_record/1` never raises on color extraction failure.
- [ ] #2 The function returns a documented result tuple for both success and failure paths.
- [ ] #3 Tests cover a failed color extraction scenario.

<!-- AC:END -->
