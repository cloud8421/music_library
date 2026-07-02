---
id: ML-180
title: Remove backup function from application
status: Done
assignee: []
created_date: "2026-05-12 04:57"
updated_date: "2026-05-15 06:11"
labels:
  - api
  - ui
dependencies: []
modified_files:
  - lib/music_library_web/router.ex
  - lib/music_library_web/controllers/archive_controller.ex
  - lib/music_library_web/live/maintenance_live/index.ex
  - test/music_library_web/controllers/archive_controller_test.exs
  - docs/architecture.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Management scripts and tools superseded this functionality. It can be removed from UI, and related endpoint can be deleted.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The /backup and /api/v1/backup routes return 404
- [x] #2 The Maintenance page no longer shows a Backup button in the Database section
- [x] #3 `mix compile --warnings-as-errors` passes with no ArchiveController references
- [x] #4 `mix test` passes with no ArchiveControllerTest references
- [x] #5 The record format `:backup` type still works (record_component format labels still show "Backup" for backup-format records)
- [x] #6 `docs/architecture.md` no longer lists ArchiveController in the routes table

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### Overview

Remove the in-app database backup download feature from the web UI and API. Management scripts (`scripts/prod/backup`, Litestream) already supersede this functionality with safer, more reliable mechanisms. This is a deletion-only change with no replacement code.

### Architecture impact analysis

| Touchpoint                                                       | Impact                                                                                                                     |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `lib/music_library_web/controllers/archive_controller.ex`        | **Delete entire file** — module contains only `backup/2` and its private `database_path/0` helper                          |
| `lib/music_library_web/router.ex`                                | Remove two `get "/backup", ArchiveController, :backup` routes (one under `:logged_in` pipeline, one under `:api` pipeline) |
| `lib/music_library_web/live/maintenance_live/index.ex`           | Remove the `<.button href={~p"/backup"}>` element from the Database section                                                |
| `test/music_library_web/controllers/archive_controller_test.exs` | **Delete entire file**                                                                                                     |
| Schemas                                                          | No changes                                                                                                                 |
| Database                                                         | No changes                                                                                                                 |
| PubSub                                                           | No changes                                                                                                                 |
| Supervision tree                                                 | No changes                                                                                                                 |
| External APIs                                                    | No changes                                                                                                                 |
| `docs/architecture.md`                                           | Remove the `ArchiveController` row from the routes table                                                                   |

### Scope clarification

The `:backup` atom in `Record.@formats` (`[:cd, :backup, :vinyl, ...]`) and the associated `format_label(:backup)` functions in `record_components.ex` and `records_on_this_day_email.ex` are **not** related to the backup download feature. They represent a record format type (backup copies of records). These are left untouched.

---

### Step 1: Remove routes (before deleting the controller, to keep compilation passing)

In `lib/music_library_web/router.ex`, remove:

- `get "/backup", ArchiveController, :backup` from the `:logged_in` pipeline scope (line 66)
- `get "/backup", ArchiveController, :backup` from the API scope (line 141)

**Verification:** `mix compile --warnings-as-errors` passes. `mix phx.routes` no longer lists `/backup` or `/api/v1/backup`.

---

### Step 2: Delete `ArchiveController`

Delete `lib/music_library_web/controllers/archive_controller.ex`.

**Verification:** `mix compile --warnings-as-errors` passes with no reference to `ArchiveController`.

---

### Step 3: Remove backup button from maintenance UI

In `lib/music_library_web/live/maintenance_live/index.ex`, remove the line:

```heex
<.button href={~p"/backup"}>
  {gettext("Backup")}
</.button>
```

from the Database section.

**Verification:** `mix compile --warnings-as-errors` passes. Start `mix phx.server`, log in, navigate to `/maintenance`, and confirm the Database section shows only Vacuum and Optimize buttons (no Backup button) and the page renders without errors.

---

### Step 4: Delete archive controller tests

Delete `test/music_library_web/controllers/archive_controller_test.exs`.

**Verification:** `mix test` passes with no references to the deleted test module.

---

### Step 5: Update documentation

In `docs/architecture.md`, remove the `ArchiveController` row from the routes table (line 347).

**Verification:** Manual review of `docs/architecture.md` confirms the row is removed and the table formatting remains intact.

---

### Performance profile

No impact. This is a deletion-only change. No new code, no new queries, no runtime overhead.

### Benchmarking requirements

None. No new code paths to benchmark.

### Cost profile

No cost impact. No API calls, compute, or storage changes.

### Production Changes

None required. No migrations, no environment variables, no service provisioning. The management scripts (`scripts/prod/backup`, Litestream) remain operational and are the recommended backup mechanisms.

**Rollback:** Revert the commit. All changes are deletions — reverting restores the feature exactly as it was.

### Documentation updates

- **`docs/architecture.md`**: Remove the `ArchiveController` row from the routes table. No other architecture docs need changes.
- No changes to `docs/project-conventions.md`, `docs/production-infrastructure.md`, `docs/available-tasks.md`, or README needed.

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Removed the in-app database backup download feature:

1. **Router** (`lib/music_library_web/router.ex`): Removed `get "/backup", ArchiveController, :backup` from both the `:logged_in` pipeline and the `:api` scope.
2. **Controller** (`lib/music_library_web/controllers/archive_controller.ex`): Deleted — module only contained `backup/2` and a private `database_path/0` helper.
3. **Maintenance UI** (`lib/music_library_web/live/maintenance_live/index.ex`): Removed the `<.button href={~p"/backup"}>` element from the Database section.
4. **Tests** (`test/music_library_web/controllers/archive_controller_test.exs`): Deleted.
5. **Docs** (`docs/architecture.md`): Removed the `ArchiveController` row from the controller routes table.

All 982 tests pass. No ArchiveController references remain. The `:backup` record format atom and `format_label(:backup)` are intentionally untouched (they represent a record format type, not the backup download feature).

<!-- SECTION:FINAL_SUMMARY:END -->
