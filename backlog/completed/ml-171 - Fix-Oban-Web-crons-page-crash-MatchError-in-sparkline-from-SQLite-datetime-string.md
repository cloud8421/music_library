---
id: ML-171
title: >-
  Fix Oban Web crons page crash: MatchError in sparkline from SQLite datetime
  string
status: Done
assignee: []
created_date: "2026-05-09 05:28"
updated_date: "2026-05-11 13:22"
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

This will be resolved when oban_web ships https://github.com/oban-bg/oban_web/commit/9e9b7ad470ac87cfcad67bec9140dc318549dc09

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Visiting /dev/oban/crons no longer crashes with MatchError
- [ ] #2 Cron history sparklines render correctly showing job state colors

<!-- AC:END -->
