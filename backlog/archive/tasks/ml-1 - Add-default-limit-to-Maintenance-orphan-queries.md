---
id: ML-1
title: "Add default :limit to Maintenance orphan queries"
status: To Do
assignee: []
created_date: "2026-04-20 08:44"
updated_date: "2026-04-24 06:59"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/183"
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Closed as not-planned (YAGNI).

The proposed fix was to add a default `:limit` (e.g. 1000) to `get_artists_missing_musicbrainz_id/1` and `get_albums_missing_musicbrainz_id/1` in `lib/music_library/maintenance.ex` to defend against future unbounded call sites.

Assessment: the dataset ceiling is <5,000 records and <1,000 artists for the next 2-3 years. An unbounded scan of the `tracks` table grouped by artist/album JSON fields is well within acceptable cost for this size. Adding a default limit would silently cap results on a dataset that should never need capping, and the only current callers (`lib/mix/tasks/scrobble/audit.ex:127,149`) already invoke without `:limit` on purpose.

A follow-up could remove the `:limit` option entirely to simplify the API — not tracked here; revisit if the option starts causing confusion.

<!-- SECTION:FINAL_SUMMARY:END -->
