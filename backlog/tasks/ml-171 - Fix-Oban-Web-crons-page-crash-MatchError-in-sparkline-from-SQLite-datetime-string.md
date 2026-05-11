---
id: ML-171
title: >-
  Fix Oban Web crons page crash: MatchError in sparkline from SQLite datetime
  string
status: To Do
assignee: []
created_date: "2026-05-09 05:28"
updated_date: "2026-05-11 06:46"
labels:
  - bug
  - oban-web
  - ready
dependencies: []
references:
  - >-
    https://github.com/oban-bg/oban_web/blob/main/lib/oban/web/live/crons/table_component.ex#L78-L85
  - >-
    https://github.com/oban-bg/oban_web/blob/main/lib/oban/web/queries/cron_query.ex#L164-L177
modified_files:
  - lib/music_library_web/live/oban/crons/table_component.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

## Summary

The `/dev/oban/crons` dashboard page crashes with `Elixir.MatchError` when rendering cron job history sparklines. This happens because Oban Web's `TableComponent.sparkline/1` calls `DateTime.from_naive!/2` which expects a `NaiveDateTime` struct, but receives a raw ISO 8601 string from SQLite.

## Root Cause

In `Oban.Web.CronQuery.cron_history/2` (deps/oban_web/lib/oban/web/queries/cron_query.ex:164-177), the query selects:

```elixir
finished_at: fragment("COALESCE(?, ?, ?)", j.completed_at, j.cancelled_at, j.discarded_at)
```

SQLite stores `utc_datetime_usec` fields as ISO 8601 text. While regular field references like `j.scheduled_at` are properly decoded to `DateTime` structs by Ecto, the `fragment()` call bypasses type decoding and returns a raw string like `"2026-05-08T11:00:00.708342Z"`.

The sparkline function at `Oban.Web.Crons.TableComponent` line 81 then fails:

```elixir
(job.finished_at || job.attempted_at || job.scheduled_at)
|> DateTime.from_naive!("Etc/UTC")  # 💥 expects NaiveDateTime, gets string
```

## Error Details

- **ErrorTracker ID**: 4039
- **Occurrences**: 2 (both on 2026-05-08)
- **View**: Oban.Web.DashboardLive (crons page)
- **Fingerprint**: `2C5253F1AB9B5D61231B7579E912FD2F7C155738DBB4325275F14E844C5D7B0C`

## Approach

The `sparkline/1` function is marked as `@doc overridable: 1` in Oban Web, so we can override it in the app. The fix should handle both `DateTime` structs (PostgreSQL) and ISO 8601 strings (SQLite) by parsing strings through `DateTime.from_iso8601!/1` first.

Alternatively, the fix could be applied upstream in Oban Web's `CronQuery` to use a typed fragment or cast the `COALESCE` result.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Visiting /dev/oban/crons no longer crashes with MatchError
- [ ] #2 Cron history sparklines render correctly showing job state colors
- [ ] #3 The fix handles both DateTime structs (PostgreSQL) and ISO 8601 strings (SQLite)
- [ ] #4 The overridden sparkline/1 function preserves the same visual output as upstream
<!-- AC:END -->
