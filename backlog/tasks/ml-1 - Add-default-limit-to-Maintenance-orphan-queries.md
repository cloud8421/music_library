---
id: ML-1
title: 'Add default :limit to Maintenance orphan queries'
status: To Do
assignee: []
created_date: '2026-04-20 08:44'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/183'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

Two Maintenance queries are unbounded when called without the `:limit` option. Currently invoked only from a Mix task, so not user-facing, but defensively adding a default prevents accidental full-table scans on future call sites.

## Evidence

- `lib/music_library/maintenance.ex:77` — `get_artists_missing_musicbrainz_id/1`
- `lib/music_library/maintenance.ex:108` — `get_albums_missing_musicbrainz_id/1`

Both accept an `opts` keyword list with `:limit`, but neither applies a default. Callers in `lib/mix/tasks/scrobble/audit.ex` pass explicit limits, so today is fine.

## Fix

Apply a sensible default (e.g. 1000) to the `:limit` option if not provided:

```elixir
def get_artists_missing_musicbrainz_id(opts \\ []) do
  limit = Keyword.get(opts, :limit, 1000)
  # ...
end
```
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both functions apply a default limit when none is supplied
- [ ] #2 Existing callers continue to override when they need a different value
<!-- AC:END -->
