---
id: ML-195
title: Add Credo check for LiveComponent toast helper usage
status: Done
assignee:
  - pi
created_date: "2026-05-21 06:57"
updated_date: "2026-05-21 07:05"
labels: []
dependencies: []
priority: medium
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add a custom Credo check that flags calls to `put_toast/3` from LiveComponent modules so contributors use the LiveComponent-safe `put_toast!/2` helper instead.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Credo fails when a LiveComponent module calls `put_toast/3`.
- [x] #2 Credo does not flag allowed `put_toast!/2` calls inside LiveComponents.
- [x] #3 Credo does not flag `put_toast/3` usage outside LiveComponent modules.
- [x] #4 Automated tests cover the new check behavior.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Review Credo configuration and any existing custom checks/tests to match project conventions.
2. Add a custom Credo check that detects modules using `use MusicLibraryWeb, :live_component` and reports calls to `put_toast/3`, including pipeline form when applicable.
3. Register the check in Credo config so `mix credo` runs it.
4. Add focused tests for disallowed LiveComponent usage, allowed `put_toast!/2`, and allowed non-LiveComponent `put_toast/3` usage.
5. Run the relevant test file and Credo check to validate behavior.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented `MusicLibrary.Credo.NoLiveComponentPutToast`, registered it in `.credo.exs`, and updated existing `RecordForm` LiveComponent toast calls to `put_toast!/2` so the new rule can be enabled cleanly. Validation: `mix test test/music_library/credo/no_live_component_put_toast_test.exs`; `mix test test/music_library_web/live/collection_live/show_test.exs --max-failures 1`; `mix test test/music_library_web/live/collection_live/index_test.exs --max-failures 1`; `mix credo --strict`.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Summary:

- Added `MusicLibrary.Credo.NoLiveComponentPutToast`, a custom Credo warning that detects `put_toast/3` calls inside LiveComponent modules and covers direct, piped, qualified, and captured call forms.
- Registered the custom check in `.credo.exs`.
- Cleaned up existing `RecordForm` LiveComponent toast usage by switching to `put_toast!/2` before returning/pushing patches.
- Added focused Credo check tests for disallowed LiveComponent usage and allowed LiveComponent/non-LiveComponent cases.

Validation:

- `mix test test/music_library/credo/no_live_component_put_toast_test.exs`
- `mix test test/music_library_web/live/collection_live/show_test.exs --max-failures 1`
- `mix test test/music_library_web/live/collection_live/index_test.exs --max-failures 1`
- `mix credo --strict`

Docs:

- No documentation update needed; `docs/project-conventions.md` already documents the LiveView vs LiveComponent toast helper rule.

<!-- SECTION:FINAL_SUMMARY:END -->
