---
id: ML-191
title: 'Fix SQLite "database busy" error in ListeningStats.update/1 (Error #4075)'
status: Done
assignee: []
created_date: "2026-05-19 15:34"
updated_date: "2026-05-19 15:44"
labels:
  - bug
  - database
  - production-error
dependencies: []
references:
  - "https://www.sqlite.org/pragma.html#pragma_busy_timeout"
  - "https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html"
modified_files:
  - config/runtime.exs
  - config/prod.exs
priority: medium
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Production error #4075: `Elixir.Exqlite.Error` "Database busy" when `ListeningStats.update/1` performs a 100-row batch `INSERT` into `scrobbled_tracks` during the daily `RefreshScrobbles` cron job at 02:00 UTC.

**Root cause:** Two cron jobs collide on `MusicLibrary.Repo`:

- `RepoVacuum` fires at `0 3 * * *` Europe/London (2 AM UTC during BST) and calls `MusicLibrary.Repo.vacuum()` — **acquires an exclusive lock on the entire DB file**
- `RefreshScrobbles` fires at `*/5 * * * *` every 5 minutes (including 2 AM UTC) and calls `ListeningStats.update/1` → `Repo.insert_all` on the same Repo

When VACUUM holds the exclusive lock and `insert_all` tries to write, SQLite throws `SQLITE_BUSY` immediately because **no `busy_timeout` is configured** in production `config/runtime.exs` (only test has it). The default busy_timeout is 0 = fail immediately instead of waiting.

The collision is deterministic: it happens every day at 2 AM UTC (3 AM London BST). During GMT (winter), the same collision would happen at 3 AM UTC. `RefreshScrobbles` runs every 5 minutes so it always collides with any scheduled maintenance job on the same Repo.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 `busy_timeout: 5_000` is set for `MusicLibrary.Repo` in `config/runtime.exs` production config
- [x] #2 `RepoVacuum` cron schedule in `config/prod.exs` is set to `3 3 * * *` (3 minutes past the hour) to avoid collision with `RefreshScrobbles` every-5-min cadence
- [ ] #3 Error #4075 no longer occurs in production after deploy

<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

**Fix:** SQLite "database busy" error (#4075) on `scrobbled_tracks` INSERT during daily `RefreshScrobbles` cron job.

**Root cause:** `RepoVacuum` (3 AM London = 2 AM UTC BST) runs `VACUUM` which acquires an exclusive DB lock. `RefreshScrobbles` fires every 5 minutes (`*/5`) including at the hour mark. Without `busy_timeout`, SQLite throws `SQLITE_BUSY` immediately instead of waiting.

**Changes:**

- `config/runtime.exs`: Added `busy_timeout: 5_000` to `MusicLibrary.Repo` — SQLite now waits up to 5s on lock contention instead of failing immediately
- `config/prod.exs`: Moved `RepoVacuum` from `0 3 * * *` to `3 3 * * *` — VACUUM runs at :03 past the hour, 2 minutes before the next `RefreshScrobbles` at :05, avoiding the collision

<!-- SECTION:FINAL_SUMMARY:END -->
